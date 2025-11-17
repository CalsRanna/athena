import 'package:athena/entity/server_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopServerFormDialog extends StatefulWidget {
  final ServerEntity? server;
  const DesktopServerFormDialog({super.key, this.server});

  @override
  State<DesktopServerFormDialog> createState() =>
      _DesktopServerFormDialogState();
}

class _DesktopServerFormDialogState
    extends State<DesktopServerFormDialog> {
  final nameController = TextEditingController();

  late final viewModel = GetIt.instance<ServerViewModel>();

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
    var text = widget.server == null ? 'Add MCP Server' : 'Edit MCP Server';
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
    nameController.text = widget.server?.name ?? '';
  }

  Future<void> storeServer() async {
    if (widget.server != null) {
      var copiedServer = widget.server!.copyWith(name: nameController.text);
      await viewModel.updateServer(copiedServer);
    } else {
      var newServer = ServerEntity(
        id: 0,
        name: nameController.text,
        enabled: true,
        command: '',
        arguments: [],
        environmentVariables: {},
        
      );
      await viewModel.createServer(newServer);
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
      onTap: storeServer,
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
