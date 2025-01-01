import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface.withValues(alpha: 0.4);
    Widget child = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedCopy01,
      size: 12.0,
    );
    if (copied) {
      child = Row(
        children: [
          HugeIcon(
            color: color,
            icon: HugeIcons.strokeRoundedTick01,
            size: 12.0,
          ),
          const SizedBox(width: 4),
          const Text('Copied!', style: TextStyle(fontSize: 12, height: 1))
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
