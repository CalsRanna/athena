import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaInput extends StatefulWidget {
  final bool autoFocus;
  final TextEditingController controller;
  final int maxLines;
  final int minLines;
  final void Function()? onBlur;
  final void Function(String)? onSubmitted;
  final String? placeholder;
  final double? radius;
  const AthenaInput({
    super.key,
    this.autoFocus = false,
    required this.controller,
    this.maxLines = 1,
    this.minLines = 1,
    this.onSubmitted,
    this.onBlur,
    this.placeholder,
    this.radius,
  });

  @override
  State<AthenaInput> createState() => _AthenaInputState();
}

class _AthenaInputState extends State<AthenaInput> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        widget.onBlur?.call();
      }
    });
    if (widget.autoFocus) {
      focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(widget.radius ?? 24),
    );
    var hintTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      height: 1.75,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: widget.placeholder,
      hintStyle: hintTextStyle,
    );
    const inputTextStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      height: 1.7,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 16,
      cursorColor: ColorUtil.FFF5F5F5,
      decoration: inputDecoration,
      focusNode: focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onSubmitted: widget.onSubmitted,
      onTapOutside: handleTapOutside,
      style: inputTextStyle,
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: textField,
    );
  }

  void handleTapOutside(PointerDownEvent event) {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}
