import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';

class MobileModelDialog extends StatelessWidget {
  final Map<String, List<ModelEntity>> groupedModels;
  final void Function(ModelEntity)? onTap;
  const MobileModelDialog({super.key, required this.groupedModels, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (groupedModels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AthenaSpace.xxl),
        child: Text(
          'No enabled models. Add one under Settings → Providers first.',
          textAlign: TextAlign.center,
          style: AthenaTextStyle.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    final titleTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textWeak,
    );
    final List<Widget> children = [const SizedBox(height: 16)];
    for (var entry in groupedModels.entries) {
      final title = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(entry.key, style: titleTextStyle),
      );
      children.add(title);
      final modelWidgets = entry.value.map((model) => _itemBuilder(model));
      children.addAll(modelWidgets);
    }
    return ListView(shrinkWrap: true, children: children);
  }

  Widget _itemBuilder(ModelEntity model) {
    return AthenaBottomSheetTile(
      onTap: () => onTap?.call(model),
      title: model.name,
    );
  }
}
