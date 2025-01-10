import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopModelFormDialog extends StatefulWidget {
  final Model? model;
  const DesktopModelFormDialog({super.key, this.model});

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
      color: Color(0xFF282F32),
    );
    var children = [
      _buildNameInput(),
      const SizedBox(height: 12),
      _buildValueInput(),
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
    ADialog.dismiss();
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
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
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    if (widget.model == null) {
      var newModel = Model()
        ..name = nameController.text
        ..value = valueController.text;
      await notifier.storeModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        name: nameController.text,
        value: valueController.text,
      );
      await notifier.updateModel(copiedModel);
    }
    ADialog.dismiss();
  }

  Widget _buildButtons() {
    var edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = ASecondaryButton(
      onTap: cancelDialog,
      child: Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var storeButton = APrimaryButton(
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

  Widget _buildNameInput() {
    var children = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: nameController))
    ];
    return Row(children: children);
  }

  Widget _buildValueInput() {
    var children = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'Value')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: valueController))
    ];
    return Row(children: children);
  }
}
