import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/checkbox.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

class DesktopModelFormDialog extends ConsumerStatefulWidget {
  final Model? model;
  final Provider provider;
  const DesktopModelFormDialog({super.key, required this.provider, this.model});

  @override
  ConsumerState<DesktopModelFormDialog> createState() =>
      _DesktopModelFormDialogState();
}

class _DesktopModelFormDialogState
    extends ConsumerState<DesktopModelFormDialog> {
  final valueController = TextEditingController();
  final nameController = TextEditingController();
  final releasedAtController = TextEditingController();
  final contextController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportReasoning = false;
  var supportVisual = false;

  late final viewModel = ModelViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var text = widget.model == null ? 'Add Model' : 'Edit Model';
    var valueChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Id')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: valueController))
    ];
    var nameChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController))
    ];
    var releasedAtChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Released At')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: releasedAtController))
    ];
    var contextChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Context')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: contextController))
    ];
    var inputChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Input Price')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: inputController))
    ];
    var outputChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Output Price')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: outputController))
    ];
    var children = [
      Text(text, style: titleTextStyle),
      const SizedBox(height: 24),
      Row(children: valueChildren),
      const SizedBox(height: 12),
      Row(children: nameChildren),
      Divider(color: ColorUtil.FFFFFFFF, height: 48, thickness: 1),
      Row(children: releasedAtChildren),
      const SizedBox(height: 12),
      Row(children: contextChildren),
      const SizedBox(height: 12),
      Row(children: inputChildren),
      const SizedBox(height: 12),
      Row(children: outputChildren),
      const SizedBox(height: 12),
      _buildSupports(),
      const SizedBox(height: 12),
      _buildButtons()
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FF282F32,
    );
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
    valueController.dispose();
    nameController.dispose();
    releasedAtController.dispose();
    contextController.dispose();
    inputController.dispose();
    outputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    valueController.text = widget.model?.value ?? '';
    nameController.text = widget.model?.name ?? '';
    releasedAtController.text = widget.model?.releasedAt ?? '';
    contextController.text = widget.model?.context ?? '';
    inputController.text = widget.model?.inputPrice ?? '';
    outputController.text = widget.model?.outputPrice ?? '';
    supportReasoning = widget.model?.supportReasoning ?? false;
    supportVisual = widget.model?.supportVisual ?? false;
  }

  Future<void> storeModel() async {
    if (widget.model == null) {
      var newModel = Model()
        ..context = contextController.text
        ..inputPrice = inputController.text
        ..name = nameController.text
        ..outputPrice = outputController.text
        ..releasedAt = releasedAtController.text
        ..supportReasoning = supportReasoning
        ..supportVisual = supportVisual
        ..value = valueController.text
        ..providerId = widget.provider.id;
      await viewModel.storeModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        context: contextController.text,
        inputPrice: inputController.text,
        name: nameController.text,
        outputPrice: outputController.text,
        releasedAt: releasedAtController.text,
        supportReasoning: supportReasoning,
        supportVisual: supportVisual,
        value: valueController.text,
      );
      await viewModel.updateModel(copiedModel);
    }
    AthenaDialog.dismiss();
  }

  void updateSupportReasoning(bool value) {
    setState(() {
      supportReasoning = value;
    });
  }

  void updateSupportVisual(bool value) {
    setState(() {
      supportVisual = value;
    });
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

  Widget _buildSupports() {
    var reasoningCheckbox = AthenaCheckbox(
      value: supportReasoning,
      onChanged: updateSupportReasoning,
    );
    var visualCheckbox = AthenaCheckbox(
      value: supportVisual,
      onChanged: updateSupportVisual,
    );
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var reasoningCheckboxGroup = AthenaCheckboxGroup(
      checkbox: reasoningCheckbox,
      onTap: () => updateSupportReasoning(!supportReasoning),
      trailing: Text('Reasoning', style: textStyle),
    );
    var visualCheckboxGroup = AthenaCheckboxGroup(
      checkbox: visualCheckbox,
      onTap: () => updateSupportVisual(!supportVisual),
      trailing: Text('Visual', style: textStyle),
    );
    var wrapChildren = [reasoningCheckboxGroup, visualCheckboxGroup];
    var children = [
      SizedBox(width: 100, child: Text('Features', style: textStyle)),
      const SizedBox(width: 12),
      Expanded(child: Wrap(runSpacing: 12, spacing: 12, children: wrapChildren))
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
