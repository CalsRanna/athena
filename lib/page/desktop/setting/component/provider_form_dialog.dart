import 'package:athena/provider/provider.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopProviderFormDialog extends StatefulWidget {
  const DesktopProviderFormDialog({super.key});

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
    var titleTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: Colors.white,
      size: 24,
    );
    var closeButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: icon,
    );
    var titleChildren = [
      Text('Add Provider', style: titleTextStyle),
      Spacer(),
      closeButton,
    ];
    var nameChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: nameController))
    ];
    var keyChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Key')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: urlController))
    ];
    var urlChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Url')),
      const SizedBox(width: 12),
      Expanded(child: AInput(controller: urlController))
    ];
    var children = [
      Row(children: titleChildren),
      const SizedBox(height: 24),
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: keyChildren),
      const SizedBox(height: 12),
      Row(children: urlChildren),
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

  Future<void> storeProvider() async {
    var container = ProviderScope.containerOf(context);
    var provider = providersNotifierProvider;
    var notifier = container.read(provider.notifier);
    var newProvider = schema.Provider()
      ..enabled = false
      ..key = keyController.text
      ..name = nameController.text
      ..url = urlController.text;
    await notifier.store(newProvider);
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
}
