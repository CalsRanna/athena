import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/checkbox.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

@RoutePage()
class MobileModelFormPage extends StatefulWidget {
  final ModelEntity? model;
  final ProviderEntity? provider;
  const MobileModelFormPage({super.key, this.model, this.provider});

  @override
  State<MobileModelFormPage> createState() => _MobileModelFormPageState();
}

class _MobileModelFormPageState extends State<MobileModelFormPage> {
  final nameController = TextEditingController();
  final valueController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportReasoning = false;
  var supportVisual = false;

  late final viewModel = GetIt.instance<ModelViewModel>();

  @override
  Widget build(BuildContext context) {
    final listViewChildren = [
      AthenaFormField(
        label: 'Id',
        control: AthenaInput(controller: valueController),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Name',
        control: AthenaInput(controller: nameController),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Input Price',
        control: AthenaInput(controller: inputController),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Output Price',
        control: AthenaInput(controller: outputController),
      ),
      const SizedBox(height: 16),
      AthenaFormField(label: 'Features', control: _buildFeatures(context)),
    ];
    final listView = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    final columnChildren = [
      Expanded(child: listView),
      _buildSubmitButton(context),
    ];
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
    valueController.text = widget.model?.modelId ?? '';
    inputController.text = widget.model?.inputPrice ?? '';
    outputController.text = widget.model?.outputPrice ?? '';
    supportReasoning = widget.model?.reasoning ?? false;
    supportVisual = widget.model?.vision ?? false;
  }

  Future<void> submitModel() async {
    if (widget.model == null) {
      final now = DateTime.now();
      final newModel = ModelEntity(
        name: nameController.text,
        modelId: valueController.text,
        providerId: widget.provider!.id!,
        contextWindow: 0,
        inputPrice: inputController.text,
        outputPrice: outputController.text,
        releasedAt: '',
        reasoning: supportReasoning,
        vision: supportVisual,
        createdAt: now,
        updatedAt: now,
      );
      await viewModel.createModel(newModel);
    } else {
      final copiedModel = widget.model!.copyWith(
        name: nameController.text,
        modelId: valueController.text,
        inputPrice: inputController.text,
        outputPrice: outputController.text,
        reasoning: supportReasoning,
        vision: supportVisual,
      );
      await viewModel.updateModel(copiedModel);
    }
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
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

  Widget _buildFeatures(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final reasoningCheckbox = AthenaCheckbox(
      value: supportReasoning,
      onChanged: updateSupportReasoning,
    );
    final visualCheckbox = AthenaCheckbox(
      value: supportVisual,
      onChanged: updateSupportVisual,
    );
    final trailingTextStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final reasoningCheckboxGroup = AthenaCheckboxGroup(
      checkbox: reasoningCheckbox,
      onTap: () => updateSupportReasoning(!supportReasoning),
      trailing: Text('Reasoning', style: trailingTextStyle),
    );
    final visualCheckboxGroup = AthenaCheckboxGroup(
      checkbox: visualCheckbox,
      onTap: () => updateSupportVisual(!supportVisual),
      trailing: Text('Visual', style: trailingTextStyle),
    );
    final children = [
      reasoningCheckboxGroup,
      const SizedBox(width: 12),
      visualCheckboxGroup,
    ];
    return Row(children: children);
  }

  Widget _buildSubmitButton(BuildContext context) {
    final button = AthenaPrimaryButton(
      onTap: submitModel,
      child: const Center(child: Text('Submit')),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }
}
