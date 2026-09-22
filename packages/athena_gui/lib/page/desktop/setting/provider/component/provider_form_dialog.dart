import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class DesktopProviderFormDialog extends StatefulWidget {
  final ProviderEntity? provider;
  const DesktopProviderFormDialog({super.key, this.provider});

  @override
  State<DesktopProviderFormDialog> createState() =>
      _DesktopProviderFormDialogState();
}

class _DesktopProviderFormDialogState extends State<DesktopProviderFormDialog> {
  final nameController = TextEditingController();

  late final viewModel = GetIt.instance<ProviderViewModel>();

  @override
  Widget build(BuildContext context) {
    var nameChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController)),
    ];
    var children = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    return AthenaDesktopDialog(
      title: widget.provider == null ? 'Add Provider' : 'Edit Provider',
      onClose: cancelDialog,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.provider?.name ?? '';
  }

  Future<void> storeProvider() async {
    if (widget.provider != null) {
      var copiedProvider = widget.provider!.copyWith(name: nameController.text);
      await viewModel.updateProvider(copiedProvider);
    } else {
      var newProvider = ProviderEntity(
        id: 0,
        enabled: true,
        name: nameController.text,
        baseUrl: '',
        apiKey: '',
        createdAt: DateTime.now(),
      );
      await viewModel.storeProvider(newProvider);
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
      onTap: storeProvider,
      child: Padding(padding: edgeInsets, child: Text('Store')),
    );
    var children = [cancelButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }
}
