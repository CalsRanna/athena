import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:hugeicons/hugeicons.dart';

class DesktopProviderFormDialog extends ConsumerStatefulWidget {
  final Provider? provider;
  const DesktopProviderFormDialog({super.key, this.provider});

  @override
  ConsumerState<DesktopProviderFormDialog> createState() =>
      _DesktopProviderFormDialogState();
}

class _DesktopProviderFormDialogState
    extends ConsumerState<DesktopProviderFormDialog> {
  final nameController = TextEditingController();

  late final viewModel = ProviderViewModel(ref);

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
      var newProvider = Provider()
        ..enabled = true
        ..name = nameController.text;
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
