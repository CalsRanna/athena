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
  final nameController = TextEditingController();
  final valueController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportFunctionCall = false;
  var supportThinking = false;
  var supportVisualRecognition = false;

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
      const SizedBox(height: 12),
      Row(children: inputChildren),
      const SizedBox(height: 12),
      Row(children: outputChildren),
      const SizedBox(height: 12),
      _buildFeatures(),
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
    inputController.dispose();
    outputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.model?.name ?? '';
    valueController.text = widget.model?.value ?? '';
    inputController.text = widget.model?.inputPrice ?? '';
    outputController.text = widget.model?.outputPrice ?? '';
    supportFunctionCall = widget.model?.supportFunctionCall ?? false;
    supportThinking = widget.model?.supportThinking ?? false;
    supportVisualRecognition = widget.model?.supportVisualRecognition ?? false;
  }

  Future<void> storeModel() async {
    if (widget.model == null) {
      var newModel = Model()
        ..name = nameController.text
        ..value = valueController.text
        ..inputPrice = inputController.text
        ..outputPrice = outputController.text
        ..supportFunctionCall = supportFunctionCall
        ..supportThinking = supportThinking
        ..supportVisualRecognition = supportVisualRecognition
        ..providerId = widget.provider.id;
      await viewModel.storeModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        name: nameController.text,
        value: valueController.text,
        inputPrice: inputController.text,
        outputPrice: outputController.text,
        supportFunctionCall: supportFunctionCall,
        supportThinking: supportThinking,
        supportVisualRecognition: supportVisualRecognition,
      );
      await viewModel.updateModel(copiedModel);
    }
    AthenaDialog.dismiss();
  }

  void updateSupportFunctionCall(bool value) {
    setState(() {
      supportFunctionCall = value;
    });
  }

  void updateSupportThinking(bool value) {
    setState(() {
      supportThinking = value;
    });
  }

  void updateSupportVisualRecognition(bool value) {
    setState(() {
      supportVisualRecognition = value;
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

  Widget _buildFeatures() {
    var functionCallCheckbox = AthenaCheckbox(
      value: supportFunctionCall,
      onChanged: updateSupportFunctionCall,
    );
    var thinkingCheckbox = AthenaCheckbox(
      value: supportThinking,
      onChanged: updateSupportThinking,
    );
    var visualRecognitionCheckbox = AthenaCheckbox(
      value: supportVisualRecognition,
      onChanged: updateSupportVisualRecognition,
    );
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var functionCallCheckboxGroup = AthenaCheckboxGroup(
      checkbox: functionCallCheckbox,
      onTap: () => updateSupportFunctionCall(!supportFunctionCall),
      trailing: Text('函数调用', style: textStyle),
    );
    var thinkingCheckboxGroup = AthenaCheckboxGroup(
      checkbox: thinkingCheckbox,
      onTap: () => updateSupportThinking(!supportThinking),
      trailing: Text('推理模型', style: textStyle),
    );
    var visualRecognitionCheckboxGroup = AthenaCheckboxGroup(
      checkbox: visualRecognitionCheckbox,
      onTap: () => updateSupportVisualRecognition(!supportVisualRecognition),
      trailing: Text('图像识别', style: textStyle),
    );
    var children = [
      SizedBox(width: 100, child: Text('Features', style: textStyle)),
      const SizedBox(width: 12),
      functionCallCheckboxGroup,
      const SizedBox(width: 12),
      thinkingCheckboxGroup,
      const SizedBox(width: 12),
      visualRecognitionCheckboxGroup,
    ];
    return Row(children: children);
  }
}
