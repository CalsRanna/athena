import 'package:flutter/material.dart';

class AInput extends StatefulWidget {
  final bool autoFocus;
  final TextEditingController controller;
  final int maxLines;
  final int minLines;
  final void Function()? onBlur;
  final void Function(String)? onSubmitted;
  final String? placeholder;
  const AInput({
    super.key,
    this.autoFocus = false,
    required this.controller,
    this.maxLines = 1,
    this.minLines = 1,
    this.onSubmitted,
    this.onBlur,
    this.placeholder,
  });

  @override
  State<AInput> createState() => _AInputState();
}

class _AInputState extends State<AInput> {
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
      color: Color(0xFFADADAD).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(24),
    );
    var hintTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      height: 1.7,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: widget.placeholder,
      hintStyle: hintTextStyle,
    );
    const inputTextStyle = TextStyle(
      color: Color(0xFFF5F5F5),
      fontSize: 14,
      height: 1.7,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 16,
      cursorColor: Color(0xFFF5F5F5),
      decoration: inputDecoration,
      focusNode: focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onSubmitted: widget.onSubmitted,
      style: inputTextStyle,
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: textField,
    );
  }
}
