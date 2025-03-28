import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/checkbox.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

@RoutePage()
class MobileModelFormPage extends ConsumerStatefulWidget {
  final Model? model;
  final Provider? provider;
  const MobileModelFormPage({super.key, this.model, this.provider});

  @override
  ConsumerState<MobileModelFormPage> createState() =>
      _MobileModelFormPageState();
}

class _MobileModelFormPageState extends ConsumerState<MobileModelFormPage> {
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
    var listViewChildren = [
      AthenaFormTileLabel.large(title: 'Id'),
      SizedBox(height: 12),
      AthenaInput(controller: valueController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'Name'),
      SizedBox(height: 12),
      AthenaInput(controller: nameController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'Input Price'),
      SizedBox(height: 12),
      AthenaInput(controller: inputController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'Output Price'),
      SizedBox(height: 12),
      AthenaInput(controller: outputController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'Features'),
      SizedBox(height: 12),
      _buildFeatures(),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildSubmitButton()];
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text(widget.model?.name ?? 'New Model')),
      body: SafeArea(top: false, child: Column(children: columnChildren)),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
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

  Future<void> submitModel() async {
    if (widget.model == null) {
      var newModel = Model()
        ..name = nameController.text
        ..value = valueController.text
        ..inputPrice = inputController.text
        ..outputPrice = outputController.text
        ..supportFunctionCall = supportFunctionCall
        ..supportThinking = supportThinking
        ..supportVisualRecognition = supportVisualRecognition
        ..providerId = widget.provider!.id;
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
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
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
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var children = [
      functionCallCheckbox,
      const SizedBox(width: 12),
      Text('函数调用', style: titleTextStyle),
      const SizedBox(width: 12),
      thinkingCheckbox,
      const SizedBox(width: 12),
      Text('推理模型', style: titleTextStyle),
      const SizedBox(width: 12),
      visualRecognitionCheckbox,
      const SizedBox(width: 12),
      Text('图像识别', style: titleTextStyle),
    ];
    return Row(children: children);
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = AthenaPrimaryButton(
      onTap: submitModel,
      child: Center(child: Text('Submit', style: textStyle)),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }
}
