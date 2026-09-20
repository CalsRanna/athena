import 'package:athena_gui/component/reasoning_card.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 将同一 Assistant 回合内按时间序排列的推理与工具调用收纳为一张默认折叠的卡片。
///
/// - 进行中（[live]）：折叠头显示当前步骤（`Thinking` 或 `工具名 参数预览`）并带
///   shimmer；结束后显示汇总（`Thought 3.2 seconds · 2 tool calls`）。
/// - 展开后按时间序逐行列出推理卡与工具行，各自可再展开查看推理正文 / 结果。
/// - 展开状态只保留在 Widget 内存态。
class StepGroupCard extends StatefulWidget {
  final List<AssistantStep> steps;
  final bool live;

  const StepGroupCard({super.key, required this.steps, this.live = false})
    : assert(steps.length > 1);

  /// 结束态折叠头文案：思考总耗时与工具调用数，按存在的部分拼接。
  static String summaryLabel(List<AssistantStep> steps) {
    var toolCount = 0;
    var reasoningCount = 0;
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
      }
    }
    final parts = <String>[
      if (toolCount > 0)
        toolCount == 1 ? 'Used 1 tool' : 'Used $toolCount tools',
      if (reasoningCount > 0)
        'Thought ${(thinkingMs / 1000).toStringAsFixed(1)} seconds',
    ];
    return parts.join(' · ');
  }

  @override
  State<StepGroupCard> createState() => _StepGroupCardState();
}

class _StepGroupCardState extends State<StepGroupCard> {
  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool _expanded = false;

  /// 与单工具卡一致：序列进行中或仍有工具未返回时显示 shimmer。
  bool get _running =>
      widget.live ||
      widget.steps.any((step) => step is ToolCallStep && !step.hasResult);

  bool get _hasTool => widget.steps.any((step) => step is ToolCallStep);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildHeader(context), if (_expanded) _buildItems()],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(_radius),
        mouseCursor: SystemMouseCursors.click,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Row(
          children: [
            Expanded(
              child: ToolHeaderShimmer(
                active: _running,
                child: Row(
                  children: [
                    Icon(
                      _hasTool
                          ? HugeIcons.strokeRoundedTools
                          : HugeIcons.strokeRoundedSparkles,
                      size: 15,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    ..._buildHeaderLabel(foreground),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 进行中显示当前（最后一个）步骤；工具步骤沿用"工具名 + 参数预览"的两段式。
  List<Widget> _buildHeaderLabel(Color foreground) {
    final last = widget.steps.last;
    if (widget.live && last is ToolCallStep) {
      return [
        Text(
          last.toolName,
          maxLines: 1,
          style: TextStyle(
            fontSize: AthenaFontSize.label,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ToolCard.argPreview(last.toolName, last.arguments),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: athenaMono(fontSize: _fontSize, color: foreground),
          ),
        ),
      ];
    }
    final text = widget.live
        ? 'Thinking'
        : StepGroupCard.summaryLabel(widget.steps);
    return [
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AthenaFontSize.label, color: foreground),
        ),
      ),
    ];
  }

  Widget _buildItems() {
    final steps = widget.steps;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in steps.indexed)
            switch (step) {
              ReasoningStep(:final message) => Padding(
                key: ValueKey(
                  'reasoning-${message.id ?? identityHashCode(message)}',
                ),
                padding: const EdgeInsets.only(top: 8),
                child: ReasoningCard(
                  message: message,
                  thinking: widget.live && index == steps.length - 1,
                ),
              ),
              ToolCallStep tool => _ToolStepRow(
                key: ValueKey(tool.id),
                step: tool,
              ),
            },
        ],
      ),
    );
  }
}

class _ToolStepRow extends StatefulWidget {
  final ToolCallStep step;

  const _ToolStepRow({super.key, required this.step});

  @override
  State<_ToolStepRow> createState() => _ToolStepRowState();
}

class _ToolStepRowState extends State<_ToolStepRow> {
  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.step.hasResult && _expanded) _buildResult(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: widget.step.hasResult
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(_radius),
        mouseCursor: widget.step.hasResult
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Row(
          children: [
            Icon(
              ToolCard.toolIcon(widget.step.toolName),
              size: 15,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  // 工具名完整展示，不参与弹性分配
                  Text(
                    widget.step.toolName,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AthenaFontSize.label,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 描述占满剩余宽度，只有真正超出时才省略
                  Expanded(
                    child: Text(
                      ToolCard.argPreview(
                        widget.step.toolName,
                        widget.step.arguments,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: athenaMono(fontSize: _fontSize, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final isError = widget.step.result!.startsWith('Error:');
    return GestureDetector(
      onTap: () => setState(() => _expanded = false),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 2, 4, 4),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Text(
          widget.step.result!,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: athenaMono(
            fontSize: _fontSize,
            color: isError ? colors.statusError : colors.textSecondary,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
