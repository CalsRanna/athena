import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobileModelSelectDialog extends ConsumerWidget {
  final void Function(Model)? onTap;
  const MobileModelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupedEnabledModelsNotifierProvider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(Map<String, List<Model>> models) {
    if (models.isEmpty) return const SizedBox();
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    List<Widget> children = [SizedBox(height: 16)];
    for (var entry in models.entries) {
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

  Widget _itemBuilder(Model model) {
    return AthenaBottomSheetTile(
      onTap: () => onTap?.call(model),
      title: model.name,
    );
  }
}
