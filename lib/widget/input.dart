import 'package:flutter/material.dart';

class AInput extends StatefulWidget {
  final TextEditingController controller;
  final int minLines;
  final void Function(KeyEvent)? onKeyEvent;
  final String? placeholder;
  const AInput({
    super.key,
    required this.controller,
    this.minLines = 1,
    this.onKeyEvent,
    this.placeholder,
  });

  @override
  State<AInput> createState() => _AInputState();
}

class _AInputState extends State<AInput> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFADADAD).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: widget.onKeyEvent,
        child: TextField(
          controller: widget.controller,
          cursorHeight: 16,
          cursorColor: Color(0xFFF5F5F5),
          decoration: InputDecoration.collapsed(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: Color(0xFFC2C2C2),
              fontSize: 14,
              height: 1.7,
            ),
          ),
          style: const TextStyle(
              color: Color(0xFFF5F5F5), fontSize: 14, height: 1.7),
          maxLines: 8,
          minLines: widget.minLines,
        ),
      ),
    );
  }
}
