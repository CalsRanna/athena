import 'package:athena/entity/ai_provider_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/ai_provider_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopProviderFormDialog extends StatefulWidget {
  final AIProviderEntity? provider;
  const DesktopProviderFormDialog({super.key, this.provider});

  @override
  State<DesktopProviderFormDialog> createState() =>
      _DesktopProviderFormDialogState();
}

class _DesktopProviderFormDialogState
    extends State<DesktopProviderFormDialog> {
  final nameController = TextEditingController();

  late final viewModel = GetIt.instance<AIProviderViewModel>();

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
    var text = widget.provider == null ? 'Add Provider' : 'Edit Provider';
    var titleChildren = [
      Text(text, style: titleTextStyle),
      Spacer(),
      closeButton,
    ];
    var nameChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController))
    ];
    var children = [
      Row(children: titleChildren),
      const SizedBox(height: 24),
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
      width: 520,
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
      var newProvider = AIProviderEntity(
        id: 0,
        enabled: true,
        name: nameController.text,
        baseUrl: '',
        apiKey: '',
        createdAt: DateTime.now(),
      );
      await viewModel.createProvider(newProvider);
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
