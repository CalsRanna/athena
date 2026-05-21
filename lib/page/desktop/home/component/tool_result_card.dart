import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ToolResultCard extends StatefulWidget {
  final String toolName;
  final String result;

  const ToolResultCard({
    super.key,
    required this.toolName,
    required this.result,
  });

  @override
  State<ToolResultCard> createState() => _ToolResultCardState();
}

class _ToolResultCardState extends State<ToolResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isError = widget.result.startsWith('Error:');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  isError ? HugeIcons.strokeRoundedCancel01 : HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 16,
                  color: isError ? Colors.red.shade600 : Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.toolName,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isError ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withValues(alpha: 0.7),
              ),
              child: Text(
                widget.result,
                maxLines: 15,
                style: GoogleFonts.firaCode(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
