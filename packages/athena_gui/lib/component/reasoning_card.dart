import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// 推理卡片：标题行 + 可折叠的推理正文。
///
/// [thinking] 为 true 时标题显示 Thinking 并带 shimmer，否则显示思考耗时。
/// 该状态由布局层根据"序列仍在进行且本步是最后一步"计算，而不是直接读实体的
/// reasoning 标记（正文流式期间该标记仍为 true）。
///
/// 展开状态只保留在 Widget 内存态（与步骤组卡一致），不落库；流式增量只替换
/// 消息实体、卡片位置与 key 不变，State 得以保留，思考期间也可点击展开实时
/// 查看推理进度。
class ReasoningCard extends StatefulWidget {
  final MessageEntity message;
  final bool thinking;

  const ReasoningCard({
    super.key,
    required this.message,
    required this.thinking,
  });

  /// 结束态标题：`Thought 2.0 seconds`。
  static String durationLabel(MessageEntity message) {
    final duration =
        message.reasoningUpdatedAt
            .difference(message.reasoningStartedAt)
            .inMilliseconds /
        1000;
    return 'Thought ${duration.toStringAsFixed(1)} seconds';
  }

  @override
  State<ReasoningCard> createState() => _ReasoningCardState();
}

class _ReasoningCardState extends State<ReasoningCard> {
  bool _expanded = false;

  MessageEntity get message => widget.message;

  @override
  Widget build(BuildContext context) {
    if (message.reasoningContent.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTitle(context), _buildContent(context)],
    );
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  Widget _buildContent(BuildContext context) {
    if (!_expanded) return const SizedBox();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleExpanded,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 2, 4, 4),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Text(
          message.reasoningContent,
          style: GoogleFonts.firaCode(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondary;
    final text = widget.thinking
        ? 'Thinking'
        : ReasoningCard.durationLabel(message);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: ToolHeaderShimmer(
          active: widget.thinking,
          child: Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedSparkles,
                size: 15,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.firaCode(fontSize: 12, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
