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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: widget.hasResult ? _resultColor : null,
        border: Border.all(
          color: widget.hasResult ? _borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.hasResult && _expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withValues(alpha: 0.7),
              ),
              child: Text(
                widget.result!,
                maxLines: 15,
                style: GoogleFonts.firaCode(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: widget.hasResult ? () => setState(() => _expanded = !_expanded) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _statusIcon,
            size: 16,
            color: _statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.toolName,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.hasResult ? _summaryLine : widget.arguments,
                  maxLines: widget.hasResult ? 1 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: widget.hasResult
                        ? _statusColor.withValues(alpha: 0.7)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (widget.hasResult) ...[
            const SizedBox(width: 8),
            Icon(
              _expanded
                  ? HugeIcons.strokeRoundedArrowUp01
                  : HugeIcons.strokeRoundedArrowDown01,
              size: 14,
              color: Colors.grey.shade500,
            ),
          ],
        ],
      ),
    );
  }

  bool get _isError => widget.result?.startsWith('Error:') ?? false;

  Color get _statusColor {
    if (!widget.hasResult) return Colors.grey.shade600;
    return _isError ? Colors.red.shade600 : Colors.green.shade600;
  }

  Color get _resultColor {
    if (!widget.hasResult) return Colors.transparent;
    return _isError ? Colors.red.shade50 : Colors.green.shade50;
  }

  Color get _borderColor {
    return _isError ? Colors.red.shade200 : Colors.green.shade200;
  }

  IconData get _statusIcon {
    if (!widget.hasResult) return HugeIcons.strokeRoundedLoading02;
    return _isError
        ? HugeIcons.strokeRoundedCancel01
        : HugeIcons.strokeRoundedCheckmarkCircle02;
  }

  String get _summaryLine {
    final r = widget.result!;
    final firstLine = r.split('\n').first;
    if (firstLine.length > 60) return '${firstLine.substring(0, 60)}...';
    return firstLine;
  }
}
