import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatIndicator extends StatelessWidget {
  final Model? model;
  final Sentinel? sentinel;
  const DesktopChatIndicator({super.key, this.model, this.sentinel});

  @override
  Widget build(BuildContext context) {
    var children = [
      _SentinelIndicator(sentinel: sentinel),
      _ModelIndicator(model: model),
    ];
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Row(spacing: 8, children: children),
    );
  }
}

class _ModelIndicator extends ConsumerWidget {
  final Model? model;
  const _ModelIndicator({this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (model == null) return const SizedBox();
    var provider = providerNotifierProvider(model!.providerId);
    var value = ref.watch(provider).valueOrNull;
    var text = Text(
      '${model!.name} | ${value?.name ?? ""}',
      style: TextStyle(color: Colors.white, fontSize: 14),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: Color(0xFF161616),
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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

class _SentinelIndicator extends StatelessWidget {
  final Sentinel? sentinel;
  const _SentinelIndicator({this.sentinel});

  @override
  Widget build(BuildContext context) {
    if (sentinel == null) return const SizedBox();
    const textStyle = TextStyle(color: Colors.white, fontSize: 14);
    return Text(sentinel!.name, style: textStyle);
  }
}
