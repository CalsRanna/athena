import 'package:flutter/material.dart';

class ADivider extends StatelessWidget {
  final Color? color;
  final double? width;
  const ADivider({super.key, this.color, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: color ?? getColor(context))),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: width,
    );
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.1);
  }
}
