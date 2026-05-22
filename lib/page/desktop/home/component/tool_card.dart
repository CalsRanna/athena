import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ToolCard extends StatefulWidget {
  final String toolName;
  final String arguments;
  final String? result;

  const ToolCard({
    super.key,
    required this.toolName,
    required this.arguments,
    this.result,
  });

  bool get hasResult => result != null;

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: ColorUtil.FFEDEDED,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(borderRadius),
          if (widget.hasResult && _expanded) _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader(BorderRadius outerRadius) {
    final collapsedRadius = BorderRadius.circular(8);
    final expandedRadius = BorderRadius.only(
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
    );
    final borderRadius = (widget.hasResult && _expanded)
        ? expandedRadius
        : collapsedRadius;

    return GestureDetector(
      onTap: widget.hasResult
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: ColorUtil.FFE0E0E0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _buildStatusIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.toolName}(${widget.arguments})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.firaCode(fontSize: 12),
              ),
            ),
            if (widget.hasResult) ...[
              const SizedBox(width: 8),
              Text(_resultLabel, style: GoogleFonts.firaCode(fontSize: 12)),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? HugeIcons.strokeRoundedArrowUp01
                    : HugeIcons.strokeRoundedArrowDown01,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (!widget.hasResult) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    final isError = widget.result!.startsWith('Error:');
    return Icon(
      isError
          ? HugeIcons.strokeRoundedCancel01
          : HugeIcons.strokeRoundedCheckmarkCircle02,
      size: 14,
      color: isError ? ColorUtil.FF9E9E9E : ColorUtil.FF6ABEB9,
    );
  }

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        widget.result!,
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.firaCode(fontSize: 12),
      ),
    );
  }

  String get _resultLabel {
    if (widget.result!.startsWith('Error:')) return 'error';
    return 'done';
  }
}
