import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/util/context_window_util.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/checkbox.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopModelFormDialog extends StatefulWidget {
  final ModelEntity? model;
  final ProviderEntity provider;
  const DesktopModelFormDialog({super.key, required this.provider, this.model});

  @override
  State<DesktopModelFormDialog> createState() => _DesktopModelFormDialogState();
}

class _DesktopModelFormDialogState extends State<DesktopModelFormDialog> {
  final valueController = TextEditingController();
  final nameController = TextEditingController();
  final releasedAtController = TextEditingController();
  final contextController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportReasoning = false;
  var supportVisual = false;

  late final viewModel = GetIt.instance<ModelViewModel>();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: colors.textPrimary,
      size: 24,
    );
    var closeButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: icon,
    );
    var text = widget.model == null ? 'Add Model' : 'Edit Model';
    var titleChildren = [
      Text(text, style: titleTextStyle),
      Spacer(),
      closeButton,
    ];
    var valueChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Id')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: valueController)),
    ];
    var nameChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: nameController)),
    ];
    var releasedAtChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Released At')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: releasedAtController)),
    ];
    var contextChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Context')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: contextController)),
    ];
    var inputChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Input Price')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: inputController)),
    ];
    var outputChildren = [
      SizedBox(width: 100, child: AthenaFormTileLabel(title: 'Output Price')),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: outputController)),
    ];
    var children = [
      Row(children: titleChildren),
      SizedBox(height: 24),
      Row(children: valueChildren),
      SizedBox(height: 12),
      Row(children: nameChildren),
      Divider(color: colors.textPrimary, height: 48, thickness: 1),
      Row(children: releasedAtChildren),
      const SizedBox(height: 12),
      Row(children: contextChildren),
      const SizedBox(height: 12),
      Row(children: inputChildren),
      const SizedBox(height: 12),
      Row(children: outputChildren),
      const SizedBox(height: 12),
      _buildSupports(context),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: colors.surfaceMobile,
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
    valueController.text = widget.model?.modelId ?? '';
    nameController.text = widget.model?.name ?? '';
    releasedAtController.text = widget.model?.releasedAt ?? '';
    var cw = widget.model?.contextWindow ?? 0;
    contextController.text = cw > 0 ? formatContextWindow(cw) : '';
    inputController.text = widget.model?.inputPrice ?? '';
    outputController.text = widget.model?.outputPrice ?? '';
    supportReasoning = widget.model?.reasoning ?? false;
    supportVisual = widget.model?.vision ?? false;
  }

  Future<void> storeModel() async {
    if (widget.model == null) {
      var now = DateTime.now();
      var newModel = ModelEntity(
        id: 0,
        modelId: valueController.text,
        name: nameController.text,
        providerId: widget.provider.id!,
        contextWindow: parseContextWindow(contextController.text),
        inputPrice: inputController.text,
        outputPrice: outputController.text,
        releasedAt: releasedAtController.text,
        reasoning: supportReasoning,
        vision: supportVisual,
        createdAt: now,
        updatedAt: now,
      );
      await viewModel.createModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        modelId: valueController.text,
        name: nameController.text,
        contextWindow: parseContextWindow(contextController.text),
        inputPrice: inputController.text,
        outputPrice: outputController.text,
        releasedAt: releasedAtController.text,
        reasoning: supportReasoning,
        vision: supportVisual,
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
    var children = [cancelButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }

  Widget _buildSupports(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var reasoningCheckbox = AthenaCheckbox(
      value: supportReasoning,
      onChanged: updateSupportReasoning,
    );
    var visualCheckbox = AthenaCheckbox(
      value: supportVisual,
      onChanged: updateSupportVisual,
    );
    var textStyle = TextStyle(
      color: colors.textPrimary,
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
      Expanded(
        child: Wrap(runSpacing: 12, spacing: 12, children: wrapChildren),
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
