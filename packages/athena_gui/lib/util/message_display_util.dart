import 'dart:convert';

import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';

/// 把消息划分为 UI 卡片，同时保留每条原始消息。
///
/// 连续的 assistant 消息与压缩步骤共用一张外层卡片；其他角色各自占一张。卡片内部
/// 仍逐条渲染 reasoning、正文、工具、压缩和引用，不合并或过滤消息字段。
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

/// 一次上下文压缩（来自一条 `compaction` 角色的消息）。
///
/// [isLive] 表示该压缩仍属于当前 run：未结束且 live 时视为进行中，未结束但
/// 不 live 时按"已中断"展示。
final class ContextCompactionStep extends AssistantStep {
  final CompactionStep step;
  final bool isLive;

  const ContextCompactionStep({required this.step, required this.isLive});

  /// 仍在压缩中：只有当前 run 里未到终态的压缩才算。
  bool get running => isLive && !step.isTerminal;
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

  /// 序列仍在进行：对话流式中，且尚未被正文 / 引用收口。
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

  /// 按渲染顺序排列的片段；被并入前序序列的消息与首个 delta 前的占位为空。
  final List<AssistantPart> parts;

  /// 首个 delta 到达前的一次性等待态。
  final bool waitingForFirstDelta;

  const AssistantMessageLayout({
    required this.message,
    required this.parts,
    this.waitingForFirstDelta = false,
  });
}

/// 把同一张卡片内的连续 Assistant 消息展开为渲染布局。
///
/// 分组规则：
/// - 推理、工具调用与上下文压缩都是"步骤"，严格按时间序排列；只有可见正文和
///   引用会切断序列，步骤本身不切断，因此多轮 `推理 → 工具 → 压缩 → 工具 → 推理`
///   会合并成一个序列，尾部推理也一并吸入，正文单独渲染在其后。
/// - 序列挂在首步所在消息上；后续消息被并入的步骤不再自行渲染。
/// - 压缩消息只贡献一个步骤：它的 content 是摘要、reference 是阶段元数据，
///   都不作为正文 / 引用渲染。
/// - 序列是否成组由渲染层（`StepCard`）按步骤数决定（≥ 2 成组），这里只负责切分。
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

    if (message.role == 'compaction') {
      ensureRun().steps.add(
        ContextCompactionStep(
          step: CompactionStep.fromMessage(message),
          isLive: loading && index == messages.length - 1,
        ),
      );
      continue;
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
    final parts = <AssistantPart>[
      for (final part in partsByIndex[index])
        part is _StepRun ? part.toPart() : part as AssistantPart,
    ];
    if (parts.isEmpty) continue;
    result.add(AssistantMessageLayout(message: message, parts: parts));
  }

  // 首个 delta 到达前保留当前 Assistant 占位卡，并标记为一次性等待态。
  if (result.isEmpty && loading) {
    result.add(
      AssistantMessageLayout(
        message: messages.first,
        parts: const [],
        waitingForFirstDelta: true,
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
