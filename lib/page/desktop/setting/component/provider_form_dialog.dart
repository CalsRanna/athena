import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopProviderFormDialog extends StatefulWidget {
  final Model? model;
  const DesktopProviderFormDialog({super.key, this.model});

  @override
  State<DesktopProviderFormDialog> createState() =>
      _DesktopProviderFormDialogState();
}

class _DesktopProviderFormDialogState extends State<DesktopProviderFormDialog> {
  final keyController = TextEditingController();
  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Color(0xFF282F32),
    );
    var children = [
      _buildNameInput(),
      const SizedBox(height: 12),
      _buildKeyInput(),
      const SizedBox(height: 12),
      _buildUrlInput(),
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
    keyController.dispose();
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.model?.name ?? '';
    urlController.text = widget.model?.value ?? '';
  }

  Future<void> storeProvider() async {
    var container = ProviderScope.containerOf(context);
    var provider = providerNotifierProvider;
    var notifier = container.read(provider.notifier);
    if (widget.model == null) {
      var newProvider = schema.Provider()
        ..enabled = false
        ..key = keyController.text
        ..name = nameController.text
        ..url = urlController.text;
      await notifier.store(newProvider);
    } else {
      var copiedProvider = widget.model!.copyWith(
        name: nameController.text,
        value: urlController.text,
      );
      // await notifier.updateModel(copiedProvider);
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
      onTap: storeProvider,
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

  Widget _buildUrlInput() {
    var children = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Url')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: urlController))
    ];
    return Row(children: children);
  }

  Widget _buildKeyInput() {
    var children = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Key')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: urlController))
    ];
    return Row(children: children);
  }
}
