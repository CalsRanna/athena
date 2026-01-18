import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopSentinelFormDialog extends StatefulWidget {
  final SentinelEntity? sentinel;
  const DesktopSentinelFormDialog({super.key, this.sentinel});

  @override
  State<DesktopSentinelFormDialog> createState() =>
      _DesktopSentinelFormDialogState();
}

class _DesktopSentinelFormDialogState extends State<DesktopSentinelFormDialog> {
  final nameController = TextEditingController();

  late final viewModel = GetIt.instance<SentinelViewModel>();

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
    var text = widget.sentinel == null ? 'Add Sentinel' : 'Edit Sentinel';
    var titleChildren = [
      Text(text, style: titleTextStyle),
      Spacer(),
      closeButton,
    ];
    var nameChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController)),
    ];
    var children = [
      Row(children: titleChildren),
      const SizedBox(height: 24),
      Row(children: nameChildren),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(32),
      width: 520,
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
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
    nameController.text = widget.sentinel?.name ?? '';
  }

  Future<void> storeSentinel() async {
    if (widget.sentinel != null) {
      var copiedSentinel = widget.sentinel!.copyWith(name: nameController.text);
      await viewModel.updateSentinel(copiedSentinel);
    } else {
      var newSentinel = SentinelEntity(
        id: 0,
        name: nameController.text,
        prompt: '',
        avatar: '',
        description: '',
        tags: '',
      );
      await viewModel.createSentinel(newSentinel);
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
      onTap: storeSentinel,
      child: Padding(padding: edgeInsets, child: Text('Store')),
    );
    var children = [cancelButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }
}
