import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:hugeicons/hugeicons.dart';

class DesktopModelIndicator extends ConsumerWidget {
  final Chat chat;
  const DesktopModelIndicator({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var chatProvider = chatNotifierProvider(chat.id);
    var latestChat = ref.watch(chatProvider).value;
    if (latestChat == null) return const SizedBox();
    var modelProvider = modelNotifierProvider(latestChat.modelId);
    var model = ref.watch(modelProvider).value;
    if (model == null) return const SizedBox();
    var sentinelProvider = sentinelNotifierProvider(latestChat.sentinelId);
    var sentinel = ref.watch(sentinelProvider).value;
    if (sentinel == null) return const SizedBox();
    var providerProvider = providerNotifierProvider(model.providerId);
    var provider = ref.watch(providerProvider).value;
    if (provider == null) return const SizedBox();
    if (provider.name.isEmpty) return const SizedBox();
    return _ModelIndicator(model: model, provider: provider);
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
    var functionCallIcon = Icon(
      HugeIcons.strokeRoundedFunctionCircle,
      color: ColorUtil.FFE0E0E0,
      size: 14,
    );
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 14,
    );
    var visualRecognitionIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: ColorUtil.FFE0E0E0,
      size: 14,
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: ColorUtil.FF161616,
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        spacing: 8,
        children: [
          text,
          if (model.supportFunctionCall) functionCallIcon,
          if (model.supportThinking) thinkIcon,
          if (model.supportVisualRecognition) visualRecognitionIcon,
        ],
      ),
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
