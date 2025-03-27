import 'package:athena/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

class DesktopModelContextMenu extends ConsumerWidget {
  final Offset offset;
  final Model model;
  final void Function()? onTap;
  final Provider provider;
  const DesktopModelContextMenu({
    super.key,
    required this.offset,
    required this.model,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var editOption = DesktopContextMenuTile(
      text: 'Edit',
      onTap: () => showModelFormDialog(context),
    );
    var deleteOption = DesktopContextMenuTile(
      text: 'Delete',
      onTap: () => destroyModel(context, ref),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroyModel(BuildContext context, WidgetRef ref) {
    ModelViewModel(ref).destroyModel(model);
    onTap?.call();
  }

  void showModelFormDialog(BuildContext context) {
    AthenaDialog.show(DesktopModelFormDialog(provider: provider, model: model));
    onTap?.call();
  }
}
