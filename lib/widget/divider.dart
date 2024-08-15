import 'package:flutter/material.dart';

class ADivider extends StatelessWidget {
  final double? width;
  const ADivider({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface.withOpacity(0.1);
    final border = Border(top: BorderSide(color: onSurface));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(border: border),
        width: width,
      ),
    );
  }
}
