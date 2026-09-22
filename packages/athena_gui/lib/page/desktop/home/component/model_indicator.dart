import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// composer 右下的当前模型名。只负责显示：点击由外层的 `_SquishButton` 接管，
/// 它拿得到整块（含 hover 填充）的矩形，模型菜单要锚在那上面。
class DesktopModelIndicator extends StatelessWidget {
  const DesktopModelIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();

    return Watch((context) {
      var model = chatViewModel.currentModel.value;
      var provider = chatViewModel.currentProvider.value;

      if (model == null) return const SizedBox();
      if (provider == null) return const SizedBox();
      return _ModelIndicator(model: model);
    });
  }
}

class _ModelIndicator extends StatelessWidget {
  final ModelEntity model;

  const _ModelIndicator({required this.model});

  @override
  Widget build(BuildContext context) {
    // Claude 的底部那一行只用**纯文字**（`Fable 5.1`），没有图标、不带 provider。
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Text(
        model.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
      ),
    );
  }
}
