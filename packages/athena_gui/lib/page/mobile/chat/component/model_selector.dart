import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';

class MobileModelSelectDialog extends StatelessWidget {
  final Map<String, List<ModelEntity>> groupedModels;
  final void Function(ModelEntity)? onTap;
  const MobileModelSelectDialog({
    super.key,
    required this.groupedModels,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groupedModels.isEmpty) return const SizedBox();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleTextStyle = TextStyle(
      color: colors.border,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    List<Widget> children = [SizedBox(height: 16)];
    for (var entry in groupedModels.entries) {
      var title = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(entry.key, style: titleTextStyle),
      );
      children.add(title);
      var modelWidgets = entry.value.map((model) => _itemBuilder(model));
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
