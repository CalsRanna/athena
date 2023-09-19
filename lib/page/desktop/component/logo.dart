import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final textTheme = theme.textTheme;
    final displayLarge = textTheme.displayLarge;
    return Center(
      child: Text(
        'Athena',
        style: displayLarge?.copyWith(
          color: onSurface.withOpacity(0.15),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
