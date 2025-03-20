import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

class DesktopChatIndicator extends ConsumerWidget {
  final Chat chat;
  const DesktopChatIndicator({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(modelNotifierProvider(chat.modelId)).value;
    if (model == null) return const SizedBox();
    var sentinel = ref.watch(sentinelNotifierProvider(chat.sentinelId)).value;
    if (sentinel == null) return const SizedBox();
    var provider = ref.watch(providerNotifierProvider(model.providerId)).value;
    if (provider == null) return const SizedBox();
    if (provider.name.isEmpty) return const SizedBox();
    var children = [
      _SentinelIndicator(sentinel: sentinel),
      _ModelIndicator(model: model, provider: provider),
    ];
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Row(spacing: 8, children: children),
    );
  }
}

class _ModelIndicator extends StatelessWidget {
  final Model model;
  final Provider provider;
  const _ModelIndicator({required this.model, required this.provider});

  @override
  Widget build(BuildContext context) {
    var text = Text(
      '${model.name} | ${provider.name}',
      style: TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: ColorUtil.FF161616,
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: text,
    );
    var colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      ColorUtil.FFFFFFFF.withValues(alpha: 0),
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
    const textStyle = TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14);
    return Text(sentinel!.name, style: textStyle);
  }
}
