import 'dart:io';

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

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_isDesktop ? 8 : 12);
    final cardBgColor =
        _isDesktop ? ColorUtil.FFEDEDED : ColorUtil.FF616161;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: cardBgColor,
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
    final collapsedRadius = BorderRadius.circular(_isDesktop ? 8 : 12);
    final expandedRadius = BorderRadius.only(
      topLeft: Radius.circular(_isDesktop ? 8 : 12),
      topRight: Radius.circular(_isDesktop ? 8 : 12),
    );
    final borderRadius = (widget.hasResult && _expanded)
        ? expandedRadius
        : collapsedRadius;
    final headerBgColor =
        _isDesktop ? ColorUtil.FFE0E0E0 : ColorUtil.FF757575;
    final fontSize = _isDesktop ? 12.0 : 11.0;

    return GestureDetector(
      onTap: widget.hasResult
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: headerBgColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${widget.toolName}(${widget.arguments})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.firaCode(fontSize: fontSize),
              ),
            ),
            if (widget.hasResult) ...[
              const SizedBox(width: 8),
              Text(_resultLabel,
                  style: GoogleFonts.firaCode(fontSize: fontSize)),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? HugeIcons.strokeRoundedArrowUp01
                    : HugeIcons.strokeRoundedArrowDown01,
                size: _isDesktop ? 16 : 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final fontSize = _isDesktop ? 12.0 : 11.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        widget.result!,
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.firaCode(fontSize: fontSize),
      ),
    );
  }

  String get _resultLabel {
    if (widget.result!.startsWith('Error:')) return 'error';
    return 'done';
  }
}
