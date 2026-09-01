import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// 同一条 Assistant 消息中的一个工具调用。
@immutable
class ToolGroupCardItem {
  final String id;
  final String toolName;
  final String arguments;
  final String? result;

  const ToolGroupCardItem({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.result,
  });

  bool get hasResult => result != null;
}

/// 将同一条 Assistant 消息中的多个工具调用收纳为一张默认折叠的卡片。
class ToolGroupCard extends StatefulWidget {
  final List<ToolGroupCardItem> items;

  const ToolGroupCard({super.key, required this.items})
    : assert(items.length > 1);

  @override
  State<ToolGroupCard> createState() => _ToolGroupCardState();
}

class _ToolGroupCardState extends State<ToolGroupCard> {
  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool _expanded = false;

  bool get _running => widget.items.any((item) => !item.hasResult);

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
    final foreground = colors.textSecondaryOnRaised;
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
                      HugeIcons.strokeRoundedTools,
                      size: 15,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.items.length} tool calls',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.firaCode(
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Column(
        children: [
          for (var index = 0; index < widget.items.length; index++)
            _ToolGroupRow(
              key: ValueKey(widget.items[index].id),
              item: widget.items[index],
            ),
        ],
      ),
    );
  }
}

class _ToolGroupRow extends StatefulWidget {
  final ToolGroupCardItem item;

  const _ToolGroupRow({super.key, required this.item});

  @override
  State<_ToolGroupRow> createState() => _ToolGroupRowState();
}

class _ToolGroupRowState extends State<_ToolGroupRow> {
  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        if (widget.item.hasResult && _expanded) _buildResult(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondaryOnRaised;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: widget.item.hasResult
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(_radius),
        mouseCursor: widget.item.hasResult
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Row(
          children: [
            Icon(
              ToolCard.toolIcon(widget.item.toolName),
              size: 15,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.item.toolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.firaCode(
                        fontSize: _fontSize,
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ToolCard.argPreview(
                        widget.item.toolName,
                        widget.item.arguments,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.firaCode(
                        fontSize: _fontSize,
                        color: foreground,
                      ),
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
    final isError = widget.item.result!.startsWith('Error:');
    return GestureDetector(
      onTap: () => setState(() => _expanded = false),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 2, 4, 4),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Text(
          widget.item.result!,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.firaCode(
            fontSize: _fontSize,
            color: isError ? colors.statusError : colors.textSecondaryOnRaised,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
