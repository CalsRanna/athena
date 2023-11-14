import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyButton extends StatefulWidget {
  const CopyButton({super.key, required this.code});

  final String code;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    Widget child = const Icon(Icons.content_copy_outlined, size: 20);
    if (copied) {
      child = const Icon(Icons.check_outlined, size: 20);
    }
    return Positioned(
      right: 8,
      top: 16,
      child: IconButton(
        onPressed: handlePressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }

  void handlePressed() async {
    if (copied) return;
    final data = ClipboardData(text: widget.code);
    await Clipboard.setData(data);
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      copied = false;
    });
  }
}
