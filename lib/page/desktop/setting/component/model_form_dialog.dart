import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopModelFormDialog extends StatefulWidget {
  final Model? model;
  final schema.Provider provider;
  const DesktopModelFormDialog({super.key, required this.provider, this.model});

  @override
  State<DesktopModelFormDialog> createState() => _DesktopModelFormDialogState();
}

class _DesktopModelFormDialogState extends State<DesktopModelFormDialog> {
  final nameController = TextEditingController();
  final valueController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FF282F32,
    );
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    var closeButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: icon,
    );
    var titleChildren = [
      Text('Add Model', style: titleTextStyle),
      Spacer(),
      closeButton,
    ];
    var valueChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Id')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: valueController))
    ];
    var nameChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController))
    ];
    var children = [
      Row(children: titleChildren),
      const SizedBox(height: 24),
      Row(children: valueChildren),
      const SizedBox(height: 12),
      Row(children: nameChildren),
      const SizedBox(height: 12),
      _buildButtons()
    ];
    var column = Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(32),
      width: 480,
      child: column,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: container,
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  @override
  void dispose() {
    valueController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.model?.name ?? '';
    valueController.text = widget.model?.value ?? '';
  }

  Future<void> storeModel() async {
    var container = ProviderScope.containerOf(context);
    var provider = modelsForNotifierProvider(widget.provider.id);
    var notifier = container.read(provider.notifier);
    if (widget.model == null) {
      var newModel = Model()
        ..name = nameController.text
        ..value = valueController.text
        ..providerId = widget.provider.id;
      await notifier.storeModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        name: nameController.text,
        value: valueController.text,
      );
      await notifier.updateModel(copiedModel);
    }
    AthenaDialog.dismiss();
  }

  Widget _buildButtons() {
    var edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = AthenaSecondaryButton(
      onTap: cancelDialog,
      child: Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var storeButton = AthenaPrimaryButton(
      onTap: storeModel,
      child: Padding(padding: edgeInsets, child: Text('Store')),
    );
    var children = [
      cancelButton,
      const SizedBox(width: 12),
      storeButton,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: children,
    );
  }
}
