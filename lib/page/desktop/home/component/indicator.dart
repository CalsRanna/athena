import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatIndicator extends StatelessWidget {
  final Chat? chat;
  const DesktopChatIndicator({super.key, this.chat});

  @override
  Widget build(BuildContext context) {
    var children = [
      _SentinelIndicator(chat: chat),
      SizedBox(width: 8),
      _ModelIndicator(chat: chat),
    ];
    return Row(children: children);
  }
}

class _ModelIndicator extends ConsumerWidget {
  final Chat? chat;
  const _ModelIndicator({this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = modelNotifierProvider(chat?.model ?? '');
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(Model model) {
    var text = Text(
      model.value,
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
  final Chat? chat;
  const _SentinelIndicator({this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelNotifierProvider(chat?.sentinelId ?? 0);
    var sentinel = ref.watch(provider);
    return switch (sentinel) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(Sentinel sentinel) {
    return Text(
      sentinel.name,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
  }
}
