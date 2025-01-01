import 'package:flutter/material.dart';

class ACard extends StatelessWidget {
  final double? width;
  final Widget child;
  const ACard({super.key, this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final shadow = colorScheme.shadow.withValues(alpha: 0.1);
    final boxShadow = BoxShadow(color: shadow, blurRadius: 12, spreadRadius: 4);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [boxShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: width,
      child: child,
    );
  }
}
