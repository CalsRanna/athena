import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/tag.dart';
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
    var modelText = Text(
      '${model.name} | ${provider.name}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    var children = <Widget>[
      const Icon(HugeIcons.strokeRoundedAiBrain01),
      modelText,
    ];
    var row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: children,
    );
    return AthenaTagButton.small(onTap: onTap, child: row);
  }
}
