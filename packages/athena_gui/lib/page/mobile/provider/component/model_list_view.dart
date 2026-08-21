import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/util/context_window_util.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
      var models = modelViewModel.models.value
          .where((m) => m.providerId == provider.id)
          .toList();
      if (models.isEmpty) return const SizedBox();
      List<Widget> children = [];
      for (var model in models) {
        var mobileModelTile = _ModelTile(
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
    var nameTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var nameText = Text(
      model.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameTextStyle,
    );
    var nameChildren = [
      Flexible(child: nameText),
      if (model.isPreset) SizedBox(width: 8),
      if (model.isPreset)
        Icon(
          HugeIcons.strokeRoundedCircleLock01,
          size: 16,
          color: colors.iconSecondary,
        ),
      const SizedBox(width: 8),
      AthenaTag.small(text: model.modelId),
    ];
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: colors.iconSecondary,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: colors.iconSecondary,
      size: 18,
    );
    var subtitleChildren = [
      _buildSubtitle(context),
      if (model.reasoning) thinkIcon,
      if (model.vision) visualIcon,
    ];
    var informationChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 4),
      Row(spacing: 8, children: subtitleChildren),
    ];
    var informationWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    var padding = Padding(
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
    var contextWindow = model.contextWindow;
    var inputPrice = model.inputPrice;
    var outputPrice = model.outputPrice;
    var parts = [
      if (contextWindow > 0) formatContextWindow(contextWindow),
      if (inputPrice.isNotEmpty) inputPrice,
      if (outputPrice.isNotEmpty) outputPrice,
    ];
    var textStyle = TextStyle(
      color: colors.iconSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var text = Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    return Flexible(child: text);
  }
}
