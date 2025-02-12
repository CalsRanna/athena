import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopModelSelector extends StatelessWidget {
  final void Function(Model)? onSelected;
  const DesktopModelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedAiBrain01,
      color: Color(0xFF616161),
      size: 24,
    );
    return GestureDetector(onTap: openDialog, child: hugeIcon);
  }

  void changeModel(Model model) {
    ADialog.dismiss();
    onSelected?.call(model);
  }

  void openDialog() {
    ADialog.show(_ModelSelectDialog(onTap: changeModel));
  }
}

class _ModelSelectDialog extends ConsumerWidget {
  final void Function(Model)? onTap;
  const _ModelSelectDialog({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupedEnabledModelsNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return UnconstrainedBox(child: ACard(child: child));
  }

  Widget _buildData(Map<String, List<Model>> models) {
    if (models.isEmpty) return const SizedBox();
    var titleTextStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.5),
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    List<Widget> children = [];
    for (var entry in models.entries) {
      var title = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(entry.key, style: titleTextStyle),
      );
      children.add(title);
      var modelWidgets =
          entry.value.map((model) => _itemBuilder(model)).toList();
      children.addAll(modelWidgets);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _itemBuilder(Model model) {
    return ATile(
      onTap: () => onTap?.call(model),
      title: model.name,
      width: 480,
    );
  }
}
