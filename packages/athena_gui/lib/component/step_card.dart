import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/util/compaction_step_formatter.dart';
import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 一段步骤序列的卡片：单步平铺，≥ 2 步收纳为默认折叠的组。
///
/// 同一个 widget 按 [steps] 的长度决定形态（Composite）：
/// - **单步**：头部是该步骤自己的图标 / 文案 / 运行态，展开后显示它的正文
///   （推理文本 / 工具结果 / 压缩详情）。
/// - **多步**：头部进行中显示当前（最后一个）步骤文案，结束后显示汇总
///   （`Used 2 tools · Thought 3.2 seconds · Compacted once`）；展开后按时间序
///   逐行嵌套单步 [StepCard]，各自可再展开。
///
/// 每种步骤类型（推理 / 工具 / 压缩）只在 [_face] 里有一份"表现描述"，新增
/// 类型时先加 `AssistantStep` 子类，再补这一处 switch 与汇总计数。
///
/// 展开状态只保留在 Widget 内存态，不落库；流式增量只替换消息实体、卡片位置
/// 与 key 不变，State 得以保留。序列从单步长成多步时展开态重置为折叠，避免
/// "点开过单步结果"在第 2 步到来时变成"组已展开"。
class StepCard extends StatefulWidget {
  final List<AssistantStep> steps;

  /// 序列仍在进行且本卡是它的尾部：单步推理显示 `Thinking`，组头显示当前步骤。
  final bool live;

  /// 作为组的子项：不自带 shimmer，运行态由组头统一表达。
  final bool nested;

  const StepCard({
    super.key,
    required this.steps,
    this.live = false,
    this.nested = false,
  }) : assert(steps.length > 0);

  // ─── 共享的静态工具函数 ────────────────────────────────

  /// 工具图标映射（HugeIcons strokeRounded 系列）。审批卡沿用同一映射。
  static IconData toolIcon(String toolName) {
    return switch (toolName) {
      'bash' || 'powershell' => HugeIcons.strokeRoundedCommandLine,
      'file_read' => HugeIcons.strokeRoundedFile01,
      'file_write' || 'file_update' => HugeIcons.strokeRoundedPencilEdit02,
      'web_fetch' => HugeIcons.strokeRoundedGlobe,
      'web_search' => HugeIcons.strokeRoundedSearch01,
      'skill' => HugeIcons.strokeRoundedBook01,
      'sentinel_evolve' => HugeIcons.strokeRoundedAiBrain01,
      'experience_learn' => HugeIcons.strokeRoundedAiBrain02,
      _ => HugeIcons.strokeRoundedTools,
    };
  }

  /// Shared GUI/TUI preview: call description, key argument, then compact JSON.
  static String argPreview(String toolName, String arguments) =>
      toolArgPreview(toolName, arguments);

  /// 推理结束态标题：`Thought 2.0 seconds`。
  static String thoughtLabel(MessageEntity message) {
    final duration =
        message.reasoningUpdatedAt
            .difference(message.reasoningStartedAt)
            .inMilliseconds /
        1000;
    return 'Thought ${duration.toStringAsFixed(1)} seconds';
  }

  /// 压缩头部文案：进行中 / 已中断 / 终态。
  static String compactionLabel(ContextCompactionStep step) =>
      compactionStatus(step.step, isLive: step.isLive);

  /// 组结束态折叠头文案：工具数、思考总耗时、压缩次数，按存在的部分拼接。
  static String summaryLabel(List<AssistantStep> steps) {
    var toolCount = 0;
    var reasoningCount = 0;
    var compactionCount = 0;
    var thinkingMs = 0;
    for (final step in steps) {
      switch (step) {
        case ReasoningStep(:final message):
          reasoningCount++;
          thinkingMs += message.reasoningUpdatedAt
              .difference(message.reasoningStartedAt)
              .inMilliseconds;
        case ToolCallStep():
          toolCount++;
        case ContextCompactionStep():
          compactionCount++;
      }
    }
    return <String>[
      if (toolCount > 0)
        toolCount == 1 ? 'Used 1 tool' : 'Used $toolCount tools',
      if (reasoningCount > 0)
        'Thought ${(thinkingMs / 1000).toStringAsFixed(1)} seconds',
      if (compactionCount > 0)
        compactionCount == 1
            ? 'Compacted once'
            : 'Compacted $compactionCount times',
    ].join(' · ');
  }

  /// 组进行中折叠头文案：当前（最后一个）步骤。
  static String currentLabel(AssistantStep last) => switch (last) {
    ReasoningStep() => 'Thinking',
    ToolCallStep step => argPreview(step.toolName, step.arguments),
    ContextCompactionStep step => compactionLabel(step),
  };

  @override
  State<StepCard> createState() => _StepCardState();
}

/// 卡片头部与可展开正文的表现描述；[body] 为 null 表示当前不可展开。
typedef _Face = ({
  IconData icon,
  String label,
  bool mono,
  bool running,
  Widget? body,
});

class _StepCardState extends State<StepCard> {
  bool _expanded = false;

  List<AssistantStep> get steps => widget.steps;

  bool get _single => steps.length == 1;

  @override
  void didUpdateWidget(StepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 单步长成多步：形态从"展开看正文"变成"展开看列表"，重置为默认折叠。
    if (oldWidget.steps.length == 1 && widget.steps.length > 1) {
      _expanded = false;
    }
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final face = _single ? _faceOf(steps.single) : _groupFace();
    final body = face.body;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          StepHeader(
            icon: face.icon,
            label: face.label,
            mono: face.mono,
            running: face.running && !widget.nested,
            onTap: body == null ? null : _toggle,
          ),
          if (body != null && _expanded) body,
        ],
      ),
    );
  }

  // ─── 单步 ────────────────────────────────────────────

  _Face _faceOf(AssistantStep step) => switch (step) {
    ReasoningStep(:final message) => (
      icon: HugeIcons.strokeRoundedSparkles,
      label: widget.live ? 'Thinking' : StepCard.thoughtLabel(message),
      mono: false,
      running: widget.live,
      body: _ReasoningBody(message: message, onTap: _toggle),
    ),
    ToolCallStep tool => (
      icon: StepCard.toolIcon(tool.toolName),
      label: StepCard.argPreview(tool.toolName, tool.arguments),
      mono: true,
      running: !tool.hasResult,
      body: tool.hasResult ? _resultBody(tool.result!) : null,
    ),
    ContextCompactionStep compaction => (
      icon: HugeIcons.strokeRoundedZip01,
      label: StepCard.compactionLabel(compaction),
      mono: false,
      running: compaction.running,
      body: compaction.running
          ? null
          : _resultBody(_compactionDetails(compaction)),
    ),
  };

  Widget _resultBody(String text) => StepResultBody(text: text, onTap: _toggle);

  /// 压缩详情：失败时以 `Error:` 前缀标红。
  static String _compactionDetails(ContextCompactionStep compaction) {
    final details = compactionDetails(compaction.step);
    return compaction.step.phase == CompactionPhase.failed
        ? 'Error: $details'
        : details;
  }

  // ─── 多步 ────────────────────────────────────────────

  _Face _groupFace() {
    final last = steps.last;
    final hasTool = steps.any((step) => step is ToolCallStep);
    // 序列进行中，或仍有工具 / 压缩未返回时显示 shimmer。
    final running =
        widget.live ||
        steps.any(
          (step) => switch (step) {
            ToolCallStep tool => !tool.hasResult,
            ContextCompactionStep compaction => compaction.running,
            ReasoningStep() => false,
          },
        );
    return (
      icon: hasTool
          ? HugeIcons.strokeRoundedTools
          : HugeIcons.strokeRoundedSparkles,
      label: widget.live
          ? StepCard.currentLabel(last)
          : StepCard.summaryLabel(steps),
      mono: widget.live && last is ToolCallStep,
      running: running,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in steps.indexed)
            StepCard(
              key: _childKey(step),
              steps: [step],
              live: widget.live && index == steps.length - 1,
              nested: true,
            ),
        ],
      ),
    );
  }

  static Key _childKey(AssistantStep step) => ValueKey(switch (step) {
    ReasoningStep(:final message) =>
      'reasoning-${message.id ?? identityHashCode(message)}',
    ToolCallStep tool => 'tool-${tool.id}',
    ContextCompactionStep compaction =>
      'compaction-${compaction.step.compactionId}',
  });
}

/// 推理正文：非等宽、点击整块收起。
class _ReasoningBody extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback onTap;

  const _ReasoningBody({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          message.reasoningContent,
          style: TextStyle(
            fontSize: kStepFontSize,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
