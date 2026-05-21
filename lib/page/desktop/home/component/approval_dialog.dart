import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

enum ApprovalResult { approve, approveOnce, deny }

class ApprovalDialog extends StatefulWidget {
  final String toolName;
  final String description;

  const ApprovalDialog({
    super.key,
    required this.toolName,
    required this.description,
  });

  @override
  State<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<ApprovalDialog> {
  bool _rememberChoice = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(HugeIcons.strokeRoundedAlert02, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(widget.toolName, style: GoogleFonts.firaCode(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: Text(
                widget.description,
                style: GoogleFonts.firaCode(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _rememberChoice,
              onChanged: (v) => setState(() => _rememberChoice = v ?? false),
              title: const Text('Remember choice for this session', style: TextStyle(fontSize: 13)),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ApprovalResult.deny),
          child: const Text('Deny'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = _rememberChoice ? ApprovalResult.approve : ApprovalResult.approveOnce;
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
