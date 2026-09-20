import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopModelIndicator extends StatelessWidget {
  final void Function()? onTap;

  const DesktopModelIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();

    return Watch((context) {
      var model = chatViewModel.currentModel.value;
      var provider = chatViewModel.currentProvider.value;

      if (model == null) return const SizedBox();
      if (provider == null) return const SizedBox();
      return _ModelIndicator(model: model, provider: provider, onTap: onTap);
    });
  }
}

class _ModelIndicator extends StatelessWidget {
  final ModelEntity model;
  final ProviderEntity provider;
  final void Function()? onTap;

  const _ModelIndicator({
    required this.model,
    required this.provider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AthenaContextChip(
      label: '${model.name} | ${provider.name}',
      leading: const Icon(HugeIcons.strokeRoundedAiBrain01),
      onTap: onTap,
      filled: false,
    );
  }
}
