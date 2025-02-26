import 'package:flutter/material.dart';

class AthenaDivider extends StatelessWidget {
  final double? width;
  const AthenaDivider({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface.withValues(alpha: 0.1);
    final border = Border(top: BorderSide(color: onSurface));
    var container = Container(
      decoration: BoxDecoration(border: border),
      width: width,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: container,
    );
  }
}
