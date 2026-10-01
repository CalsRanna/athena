import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/util/context_window_util.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileModelListView extends StatelessWidget {
  final void Function(ModelEntity)? onLongPress;
  final void Function(ModelEntity)? onTap;
  final ProviderEntity provider;
  final ModelViewModel modelViewModel;
  const MobileModelListView({
    super.key,
    this.onLongPress,
    this.onTap,
    required this.provider,
    required this.modelViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final models = modelViewModel.models.value
          .where((m) => m.providerId == provider.id)
          .toList();
      if (models.isEmpty) return const SizedBox();
      final List<Widget> children = [];
      for (var model in models) {
        final mobileModelTile = _ModelTile(
          model: model,
          onLongPress: () => onLongPress?.call(model),
          onTap: () => onTap?.call(model),
        );
        children.add(mobileModelTile);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      );
    });
  }
}

class _ModelTile extends StatelessWidget {
  final void Function()? onLongPress;
  final void Function()? onTap;
  final ModelEntity model;
  const _ModelTile({this.onLongPress, this.onTap, required this.model});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final nameTextStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final nameText = Text(
      model.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameTextStyle,
    );
    final nameChildren = [
      Flexible(child: nameText),
      if (model.isPreset) const SizedBox(width: 8),
      if (model.isPreset)
        Icon(
          LucideIcons.lockKeyhole,
          size: AthenaIcon.regularSize,
          color: colors.iconSecondary,
        ),
      const SizedBox(width: 8),
      AthenaTag.small(text: model.modelId),
    ];
    final thinkIcon = Icon(
      LucideIcons.brainCircuit,
      color: colors.iconSecondary,
      size: AthenaIcon.regularSize,
    );
    final visualIcon = Icon(
      LucideIcons.eye,
      color: colors.iconSecondary,
      size: AthenaIcon.regularSize,
    );
    final subtitleChildren = [
      _buildSubtitle(context),
      if (model.reasoning) thinkIcon,
      if (model.vision) visualIcon,
    ];
    final informationChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 4),
      Row(spacing: 8, children: subtitleChildren),
    ];
    final informationWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: informationWidget,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      onTap: onTap,
      child: padding,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final contextWindow = model.contextWindow;
    final inputPrice = model.inputPrice;
    final outputPrice = model.outputPrice;
    final parts = [
      if (contextWindow > 0) formatContextWindow(contextWindow),
      if (inputPrice.isNotEmpty) inputPrice,
      if (outputPrice.isNotEmpty) outputPrice,
    ];
    final textStyle = AthenaTextStyle.caption.copyWith(
      color: colors.iconSecondary,
    );
    final text = Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    return Flexible(child: text);
  }
}
