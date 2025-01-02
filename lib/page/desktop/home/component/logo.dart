import 'package:athena/provider/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: sentinel.tags.map((tag) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    colors: [
                      Color(0xFFEAEAEA).withValues(alpha: 0.17),
                      Colors.white.withValues(alpha: 0),
                    ],
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.all(1),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: Color(0xFF161616),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
                  child: Text(
                    tag,
                    style: displayLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            sentinel.description,
            style: displayLarge?.copyWith(
              color: Color(0xFFC2C2C2),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    });
  }
}
