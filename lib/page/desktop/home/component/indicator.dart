import 'package:athena/provider/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatIndicator extends StatelessWidget {
  const DesktopChatIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      _SentinelIndicator(),
      SizedBox(width: 8),
      _ModelIndicator(),
    ];
    return Row(children: children);
  }
}

class _ModelIndicator extends ConsumerWidget {
  const _ModelIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatNotifierProvider).valueOrNull;
    if (chat == null) return const SizedBox();
    var text = Text(
      chat.model,
      style: TextStyle(color: Colors.white, fontSize: 14),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: Color(0xFF161616),
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: text,
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}

class _SentinelIndicator extends ConsumerWidget {
  const _SentinelIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
    return Text(
      sentinel?.name ?? 'Athena',
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
  }
}
