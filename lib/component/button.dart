import 'package:flutter/material.dart';

class CopyButton extends StatefulWidget {
  final void Function()? onTap;
  const CopyButton({super.key, this.onTap});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    Widget child = const Icon(Icons.content_copy_outlined, size: 12);
    if (copied) {
      child = const Row(
        children: [
          Icon(Icons.check_outlined, size: 12),
          SizedBox(width: 4),
          Text('Copied!', style: TextStyle(fontSize: 12, height: 1))
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }

  void handleTap() async {
    if (copied) return;
    widget.onTap?.call();
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      copied = false;
    });
  }
}
