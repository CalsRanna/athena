import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:hugeicons/hugeicons.dart';

class MobileModelListView extends ConsumerWidget {
  final void Function(Model)? onLongPress;
  final void Function(Model)? onTap;
  final Provider provider;
  const MobileModelListView({
    super.key,
    this.onLongPress,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var modelsProvider = modelsForNotifierProvider(provider.id);
    var models = ref.watch(modelsProvider).valueOrNull;
    if (models == null) return const SizedBox();
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
  }
}

class _ModelTile extends StatelessWidget {
  final void Function()? onLongPress;
  final void Function()? onTap;
  final Model model;
  const _ModelTile({
    this.onLongPress,
    this.onTap,
    required this.model,
  });

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
      AthenaTag.small(text: model.value)
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
      if (model.supportReasoning) thinkIcon,
      if (model.supportVisual) visualIcon,
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
    var context = model.context;
    var inputPrice = model.inputPrice;
    var outputPrice = model.outputPrice;
    var parts = [
      if (context.isNotEmpty) '$context context',
      if (inputPrice.isNotEmpty) '$inputPrice input tokens',
      if (outputPrice.isNotEmpty) '$outputPrice output tokens',
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
