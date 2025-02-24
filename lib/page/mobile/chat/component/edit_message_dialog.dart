import 'package:athena/schema/chat.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';

class MobileEditMessageDialog extends StatefulWidget {
  final Message message;

  /// Message from this callback will be a copied message with new content
  final void Function(Message)? onSubmitted;
  const MobileEditMessageDialog({
    super.key,
    required this.message,
    this.onSubmitted,
  });

  @override
  State<MobileEditMessageDialog> createState() =>
      _MobileEditMessageDialogState();
}

class _MobileEditMessageDialogState extends State<MobileEditMessageDialog> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var barrier = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ADialog.dismiss(),
      child: Container(color: Colors.transparent),
    );
    var input = AInput(
      autoFocus: true,
      controller: controller,
      onSubmitted: editMessage,
    );
    var container = Container(
      color: Color(0xFF282F32),
      padding: const EdgeInsets.all(16.0),
      child: input,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [Expanded(child: barrier), container]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void editMessage(String text) {
    if (text.trim().isEmpty) return;
    ADialog.dismiss();
    var copiedMessage = widget.message.copyWith(content: text);
    widget.onSubmitted?.call(copiedMessage);
  }

  @override
  void initState() {
    super.initState();
    controller.text = widget.message.content;
  }
}
