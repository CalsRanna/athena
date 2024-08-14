import 'package:athena/provider/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final textTheme = theme.textTheme;
    final displayLarge = textTheme.displayLarge;
    return Consumer(builder: (context, ref, child) {
      final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
      if (sentinel == null) return const SizedBox();
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            sentinel.name,
            style: displayLarge?.copyWith(
              color: onSurface.withOpacity(0.15),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: sentinel.tags.map((tag) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: onSurface.withOpacity(0.05),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  tag,
                  style: displayLarge?.copyWith(
                    color: onSurface.withOpacity(0.15),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            sentinel.description,
            style: displayLarge?.copyWith(
              color: onSurface.withOpacity(0.15),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    });
  }
}
