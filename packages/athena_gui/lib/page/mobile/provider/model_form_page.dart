import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/context_window_util.dart';
import 'package:athena_gui/util/model_form_util.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/checkbox.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

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
  final releasedAtController = TextEditingController();
  final contextController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportReasoning = false;
  var supportVisual = false;
  String? idError;
  String? nameError;

  late final viewModel = GetIt.instance<ModelViewModel>();

  @override
  Widget build(BuildContext context) {
    final listViewChildren = [
      AthenaFormField(
        label: 'Model ID',
        control: AthenaInput(
          controller: valueController,
          placeholder: 'model-id',
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
        ),
        description: 'The id sent to the API, e.g. deepseek-v4-flash.',
        error: idError,
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Display name',
        control: AthenaInput(
          controller: nameController,
          placeholder: 'e.g. DeepSeek V4 Flash',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        error: nameError,
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Released',
        control: AthenaInput(
          controller: releasedAtController,
          placeholder: 'YYYY-MM-DD',
          keyboardType: TextInputType.datetime,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Context window',
        control: AthenaInput(
          controller: contextController,
          placeholder: '128K',
          autocorrect: false,
          enableSuggestions: false,
        ),
        description: 'Accepts plain tokens or K / M suffixes.',
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Input price',
        control: AthenaInput(
          controller: inputController,
          placeholder: '0.15',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autocorrect: false,
          enableSuggestions: false,
        ),
        description: 'USD per million tokens.',
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Output price',
        control: AthenaInput(
          controller: outputController,
          placeholder: '0.60',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autocorrect: false,
          enableSuggestions: false,
        ),
        description: 'USD per million tokens.',
      ),
      const SizedBox(height: 20),
      AthenaFormField(label: 'Capabilities', control: _buildFeatures(context)),
      const SizedBox(height: 16),
      const SafeArea(top: false, child: SizedBox()),
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
    releasedAtController.dispose();
    contextController.dispose();
    inputController.dispose();
    outputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.model?.name ?? '';
    valueController.text = widget.model?.modelId ?? '';
    releasedAtController.text = stripModelReleasedAt(
      widget.model?.releasedAt ?? '',
    );
    final contextWindow = widget.model?.contextWindow ?? 0;
    contextController.text = contextWindow > 0
        ? formatContextWindow(contextWindow)
        : '';
    inputController.text = stripModelPrice(widget.model?.inputPrice ?? '');
    outputController.text = stripModelPrice(widget.model?.outputPrice ?? '');
    supportReasoning = widget.model?.reasoning ?? false;
    supportVisual = widget.model?.vision ?? false;
  }

  Future<void> submitModel() async {
    final modelId = valueController.text.trim();
    final name = nameController.text.trim();
    setState(() {
      idError = modelId.isEmpty ? 'Model ID is required.' : null;
      nameError = name.isEmpty ? 'Display name is required.' : null;
    });
    if (idError != null || nameError != null) return;

    final released = stripModelReleasedAt(releasedAtController.text);
    final releasedAt = released.isEmpty ? '' : 'Released $released';
    final contextWindow = parseContextWindow(contextController.text);
    final inputPrice = formatModelPrice(inputController.text);
    final outputPrice = formatModelPrice(outputController.text);

    if (widget.model == null) {
      final now = DateTime.now();
      final newModel = ModelEntity(
        name: name,
        modelId: modelId,
        providerId: widget.provider!.id!,
        contextWindow: contextWindow,
        inputPrice: inputPrice,
        outputPrice: outputPrice,
        releasedAt: releasedAt,
        reasoning: supportReasoning,
        vision: supportVisual,
        createdAt: now,
        updatedAt: now,
      );
      await viewModel.createModel(newModel);
    } else {
      final copiedModel = widget.model!.copyWith(
        name: name,
        modelId: modelId,
        contextWindow: contextWindow,
        inputPrice: inputPrice,
        outputPrice: outputPrice,
        releasedAt: releasedAt,
        reasoning: supportReasoning,
        vision: supportVisual,
      );
      await viewModel.updateModel(copiedModel);
    }
    if (!mounted) return;
    final error = viewModel.error.value;
    if (error != null) {
      AthenaDialog.error(error);
      return;
    }
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
    final colors = context.athenaColors;
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
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [reasoningCheckboxGroup, visualCheckboxGroup],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final button = AthenaPrimaryButton(
      onTap: submitModel,
      child: Center(child: Text(widget.model == null ? 'Add model' : 'Save')),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }
}
