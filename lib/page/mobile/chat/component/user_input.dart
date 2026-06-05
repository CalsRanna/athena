import 'package:athena/page/mobile/chat/component/send_button.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class UserInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  final bool isStreaming;
  const UserInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onTerminated,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    const hintTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    const textStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textField = TextField(
      controller: controller,
      cursorColor: ColorUtil.FFFFFFFF,
      decoration: inputDecoration,
      maxLines: 2,
      minLines: 2,
      onTapOutside: (_) => handleTapOutside(context),
      style: textStyle,
      textInputAction: TextInputAction.newline,
    );
    var sendButton = SendButton(
      onSubmitted: onSubmitted,
      onTerminated: onTerminated,
      isStreaming: isStreaming,
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
    var rowChildren = [
      Expanded(child: textField),
      const SizedBox(width: 16),
      sendButton,
    ];
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }

  void handleTapOutside(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
