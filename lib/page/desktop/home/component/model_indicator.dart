import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopModelIndicator extends StatelessWidget {
  const DesktopModelIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();

    return Watch((context) {
      var model = chatViewModel.currentModel.value;
      if (model == null) return const SizedBox();

      var provider = chatViewModel.currentProvider.value;
      if (provider == null) return const SizedBox();
      if (provider.name.isEmpty) return const SizedBox();

      return _ModelIndicator(model: model, provider: provider);
    });
  }
}

class _ModelIndicator extends StatelessWidget {
  final ModelEntity model;
  final ProviderEntity provider;
  const _ModelIndicator({required this.model, required this.provider});

  @override
  Widget build(BuildContext context) {
    var text = Text(
      '${model.name} | ${provider.name}',
      style: TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14),
    );
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 14,
    );
    var visualIcon = Icon(
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
          if (model.reasoning) thinkIcon,
          if (model.vision) visualIcon,
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
