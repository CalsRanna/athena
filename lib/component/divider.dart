import 'package:flutter/material.dart';

class ADivider extends StatelessWidget {
  final double? width;
  const ADivider({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: color))),
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: width,
    );
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.1);
  }
}
