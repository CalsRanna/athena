import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';

/// 把消息划分为 UI 卡片，同时保留每条原始消息。
///
/// 连续的 assistant 消息与压缩步骤共用一张外层卡片；其他角色各自占一张。卡片内部
/// 仍逐条渲染 reasoning、正文、工具和引用，不合并或过滤消息字段。
List<List<MessageEntity>> buildMessageDisplayCards(
  List<MessageEntity> messages,
) {
  final cards = <List<MessageEntity>>[];

  for (final message in messages) {
    if (isAssistantCardMessage(message) &&
        cards.isNotEmpty &&
        isAssistantCardMessage(cards.last.first)) {
      cards.last.add(message);
    } else {
      cards.add([message]);
    }
  }

  return cards;
}

bool isAssistantCardMessage(MessageEntity message) =>
    message.role == 'assistant' || message.role == 'compaction';

// ─── Assistant 卡片内的步骤分组 ─────────────────────────────

/// Assistant 回合内的一个展示步骤：一段推理或一次工具调用。
sealed class AssistantStep {
  const AssistantStep();
}

/// 一段推理（来自一条消息的 reasoningContent）。
final class ReasoningStep extends AssistantStep {
  final MessageEntity message;

  const ReasoningStep(this.message);
}

/// 一次工具调用及其结果；[result] 为 null 表示尚未返回。
final class ToolCallStep extends AssistantStep {
  final String id;
  final String toolName;
  final String arguments;
  final String? result;

  const ToolCallStep({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.result,
  });

  bool get hasResult => result != null;
}

/// 一条 Assistant 消息按顺序渲染的片段。
sealed class AssistantPart {
  const AssistantPart();
}

/// 推理与工具调用按时间序组成的步骤序列。
///
/// 跨消息合并后挂在序列首步所在的宿主消息上；后续消息并入的步骤不再在
/// 各自消息里渲染。
final class StepsPart extends AssistantPart {
  final List<AssistantStep> steps;

  /// 序列仍在进行：对话流式中，且尚未被正文 / 引用 / 压缩步骤收口。
  final bool live;

  const StepsPart({required this.steps, required this.live});
}

/// 消息正文（Markdown）。
final class ContentPart extends AssistantPart {
  const ContentPart();
}

/// 引用列表。
final class ReferencePart extends AssistantPart {
  const ReferencePart();
}

/// 卡片内一条可见 Assistant / 压缩消息的渲染布局。
class AssistantMessageLayout {
  final MessageEntity message;

  /// 按渲染顺序排列的片段；压缩步骤与首个 delta 前的占位为空。
  final List<AssistantPart> parts;

  /// 首个 delta 到达前的一次性等待态。
  final bool waitingForFirstDelta;

  /// 首个片段是平铺的推理卡（自身无上边距）且不是卡片首条时补消息边界间距。
  final bool addBoundarySpacing;

  /// 压缩步骤是否仍在当前 run 中（只对压缩消息有意义）。
  final bool isLive;

  const AssistantMessageLayout({
    required this.message,
    required this.parts,
    this.waitingForFirstDelta = false,
    required this.addBoundarySpacing,
    this.isLive = false,
  });
}

/// 把同一张卡片内的连续 Assistant 消息展开为渲染布局。
///
/// 分组规则：
/// - 推理与工具调用是"步骤"，严格按时间序排列；只有可见正文、引用和压缩步骤
///   会切断序列，推理本身不切断，因此多轮 `推理 → 工具 → 推理 → 工具 → 推理`
///   会合并成一个序列，尾部推理也一并吸入，正文单独渲染在其后。
/// - 序列挂在首步所在消息上；后续消息被并入的推理/工具不再自行渲染。
/// - 序列是否成组由渲染层按步骤数决定（≥ 2 成组），这里只负责切分。
/// - 完全空的占位消息不切断序列（流式期间新占位随时可能被并入）。
///
/// [loading] 表示这张卡片仍在流式输出；末尾仍未收口的序列标记为 live。
List<AssistantMessageLayout> buildAssistantMessageLayouts(
  List<MessageEntity> messages, {
  required bool loading,
}) {
  assert(messages.isNotEmpty);
  final partsByIndex = List.generate(messages.length, (_) => <Object>[]);
  _StepRun? open;

  for (final (index, message) in messages.indexed) {
    if (message.role == 'compaction') {
      open = null;
      continue;
    }
    final parts = partsByIndex[index];

    _StepRun ensureRun() {
      var run = open;
      if (run == null) {
        run = _StepRun();
        parts.add(run);
        open = run;
      }
      return run;
    }

    if (message.reasoningContent.isNotEmpty) {
      ensureRun().steps.add(ReasoningStep(message));
    }
    if (message.content.isNotEmpty) {
      open = null;
      parts.add(const ContentPart());
    }
    final toolSteps = parseToolCallSteps(message);
    if (toolSteps.isNotEmpty) {
      ensureRun().steps.addAll(toolSteps);
    }
    if (message.reference.isNotEmpty) {
      open = null;
      parts.add(const ReferencePart());
    }
  }
  open?.live = loading;

  final result = <AssistantMessageLayout>[];
  for (final (index, message) in messages.indexed) {
    if (message.role == 'compaction') {
      result.add(
        AssistantMessageLayout(
          message: message,
          parts: const [],
          addBoundarySpacing: false,
          isLive: loading && index == messages.length - 1,
        ),
      );
      continue;
    }
    final parts = <AssistantPart>[
      for (final part in partsByIndex[index])
        part is _StepRun ? part.toPart() : part as AssistantPart,
    ];
    if (parts.isEmpty) continue;

    final first = parts.first;
    final flatReasoningFirst =
        first is StepsPart &&
        first.steps.length == 1 &&
        first.steps.single is ReasoningStep;
    result.add(
      AssistantMessageLayout(
        message: message,
        parts: parts,
        addBoundarySpacing: result.isNotEmpty && flatReasoningFirst,
      ),
    );
  }

  // 首个 delta 到达前保留当前 Assistant 占位卡，并标记为一次性等待态。
  if (result.isEmpty && loading) {
    result.add(
      AssistantMessageLayout(
        message: messages.first,
        parts: const [],
        waitingForFirstDelta: true,
        addBoundarySpacing: false,
      ),
    );
  }
  return result;
}

/// 解析一条消息的工具调用，并按 id 关联已返回的结果。
///
/// toolCalls / toolResults 任一 JSON 不合法时按无该部分处理，不抛异常。
List<ToolCallStep> parseToolCallSteps(MessageEntity message) {
  if (message.toolCalls.isEmpty) return const [];

  final results = <String, String>{};
  if (message.toolResults.isNotEmpty) {
    try {
      final list = jsonDecode(message.toolResults) as List<dynamic>;
      for (final result in list) {
        results[result['id'] as String] = result['result'] as String;
      }
    } catch (_) {}
  }

  try {
    final calls = jsonDecode(message.toolCalls) as List<dynamic>;
    return [
      for (final call in calls)
        ToolCallStep(
          id: call['id'] as String,
          toolName: call['name'] as String? ?? '',
          arguments: call['arguments'] as String? ?? '',
          result: results[call['id'] as String],
        ),
    ];
  } catch (_) {
    return const [];
  }
}

/// 构建期间可追加步骤的序列，最终转换为不可变的 [StepsPart]。
class _StepRun {
  final List<AssistantStep> steps = [];
  bool live = false;

  StepsPart toPart() => StepsPart(steps: List.unmodifiable(steps), live: live);
}
