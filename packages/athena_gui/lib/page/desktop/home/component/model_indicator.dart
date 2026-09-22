import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
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
    // Claude 的底部那一行只用**纯文字**（`Fable 5.1`），没有图标、不带 provider。
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            model.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
