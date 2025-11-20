import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileModelListView extends StatelessWidget {
  final void Function(ModelEntity)? onLongPress;
  final void Function(ModelEntity)? onTap;
  final ProviderEntity provider;
  const MobileModelListView({
    super.key,
    this.onLongPress,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var modelViewModel = GetIt.instance<ModelViewModel>();
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
    var nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
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
      SizedBox(width: 8),
      AthenaTag.small(text: model.modelId),
    ];
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var subtitleChildren = [
      _buildSubtitle(),
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

  Widget _buildSubtitle() {
    var context = model.contextWindow;
    var inputPrice = model.inputPrice;
    var outputPrice = model.outputPrice;
    var parts = [
      if (context > 0) '$context context',
      if (inputPrice > 0) '${inputPrice.toStringAsFixed(2)} input tokens',
      if (outputPrice > 0) '${outputPrice.toStringAsFixed(2)} output tokens',
    ];
    var textStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
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
