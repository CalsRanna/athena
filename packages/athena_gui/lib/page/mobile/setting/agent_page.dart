import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/page/mobile/chat/component/model_selector.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileAgentPage extends StatefulWidget {
  const MobileAgentPage({super.key});

  @override
  State<MobileAgentPage> createState() => _MobileAgentPageState();
}

class _MobileAgentPageState extends State<MobileAgentPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();
  late final retriesController = TextEditingController(
    text: viewModel.maxRetries.value.toString(),
  );
  late final outputLimitController = TextEditingController(
    text: viewModel.defaultOutputLimit.value.toString(),
  );
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  String? retriesError;
  String? outputLimitError;

  @override
  void initState() {
    super.initState();
    // 用户可能刚在 Providers 里启用了一家，保证下拉里是最新的模型。
    modelViewModel.loadEnabledModels();
  }

  @override
  void dispose() {
    retriesController.dispose();
    outputLimitController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('Agent')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildModelsSection(context),
            const SizedBox(height: 32),
            _buildRequestSection(context),
            const SizedBox(height: 32),
            _buildToolsSection(context),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildModelsSection(BuildContext context) {
    return Watch((context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AthenaFormTileLabel.large(title: 'Default models'),
          const SizedBox(height: 16),
          AthenaFormField(
            label: 'Session model',
            control: _ModelDropdown(
              groupedModels: modelViewModel.groupedEnabledModels.value,
              model: viewModel.chatModel.value,
              onChanged: viewModel.updateChatModelId,
              provider: viewModel.chatModelProvider.value,
            ),
            description:
                'The model new sessions and the agent loop start with.',
            descriptionGap: 8,
          ),
          const SizedBox(height: 16),
          AthenaFormField(
            label: 'Session naming model',
            control: _ModelDropdown(
              groupedModels: modelViewModel.groupedEnabledModels.value,
              model: viewModel.chatNamingModel.value,
              onChanged: viewModel.updateChatNamingModelId,
              provider: viewModel.chatNamingModelProvider.value,
            ),
            description:
                'Names a session after its first exchange. Falls back to the '
                'session model.',
            descriptionGap: 8,
          ),
          const SizedBox(height: 16),
          AthenaFormField(
            label: 'Sentinel metadata model',
            control: _ModelDropdown(
              groupedModels: modelViewModel.groupedEnabledModels.value,
              model: viewModel.sentinelMetadataGenerationModel.value,
              onChanged: viewModel.updateSentinelMetadataGenerationModelId,
              provider: viewModel.sentinelMetadataGenerationModelProvider.value,
            ),
            description:
                'Generates a Sentinel\'s name, description and tags from its '
                'system prompt.',
            descriptionGap: 8,
          ),
        ],
      );
    });
  }

  Widget _buildRequestSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AthenaFormTileLabel.large(title: 'Model requests'),
        const SizedBox(height: 16),
        AthenaFormField(
          label: 'Max attempts',
          control: AthenaInput(
            controller: retriesController,
            placeholder: '10',
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            onBlur: _commitRetries,
            onSubmitted: (_) => _commitRetries(),
          ),
          description:
              'Total tries for a model request that fails on the network, '
              'including the first attempt.',
          error: retriesError,
          descriptionGap: 8,
        ),
        const SizedBox(height: 16),
        AthenaFormField(
          label: 'Default output limit',
          control: AthenaInput(
            controller: outputLimitController,
            placeholder: '128000',
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            onBlur: _commitOutputLimit,
            onSubmitted: (_) => _commitOutputLimit(),
          ),
          description:
              'Output token limit for models without their own limit. '
              'Applies only to the Messages API format.',
          error: outputLimitError,
          descriptionGap: 8,
        ),
        const SizedBox(height: 16),
        AthenaFormField(
          label: 'Default reasoning effort',
          control: Watch(
            (_) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in reasoningEffortOptions)
                  AthenaTagButton.small(
                    selected:
                        viewModel.defaultReasoningEffort.value == option.$1,
                    onTap: () =>
                        viewModel.updateDefaultReasoningEffort(option.$1),
                    child: Text(option.$2),
                  ),
              ],
            ),
          ),
          description:
              'Reasoning effort new sessions start with. You can still change '
              'it in the composer.',
          descriptionGap: 8,
        ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AthenaFormTileLabel.large(title: 'Tools'),
        const SizedBox(height: 16),
        AthenaFormField(
          label: 'Background task reports',
          control: Watch(
            (_) => Align(
              alignment: Alignment.centerLeft,
              child: AthenaSwitch(
                value: viewModel.backgroundTaskReports.value,
                onChanged: viewModel.updateBackgroundTaskReports,
              ),
            ),
          ),
          description:
              'When a background command finishes, start a run that reads its '
              'output and reports back. That run uses this session\'s model, '
              'so it costs a request.',
        ),
        const SizedBox(height: 16),
        AthenaFormField(
          label: 'Brave Search API key',
          control: AthenaInput(
            controller: braveApiKeyController,
            obscureText: true,
            placeholder: 'BSA...',
            autocorrect: false,
            enableSuggestions: false,
            onBlur: _commitBraveApiKey,
            onSubmitted: (_) => _commitBraveApiKey(),
          ),
          description:
              'Used by web_search. Get a free key at brave.com/search/api.',
          descriptionGap: 8,
        ),
      ],
    );
  }

  Future<void> _commitRetries() async {
    final value = int.tryParse(retriesController.text.trim());
    if (value == null || value < 1) {
      setState(() => retriesError = 'Enter a whole number of at least 1.');
      return;
    }
    setState(() => retriesError = null);
    if (value == viewModel.maxRetries.value) return;
    await viewModel.updateMaxRetries(value);
  }

  Future<void> _commitOutputLimit() async {
    final value = int.tryParse(outputLimitController.text.trim());
    if (value == null || value < 1) {
      final fallback = viewModel.defaultOutputLimit.value;
      setState(() => outputLimitError = 'Enter a whole number of at least 1.');
      outputLimitController.text = fallback.toString();
      return;
    }
    setState(() => outputLimitError = null);
    if (value == viewModel.defaultOutputLimit.value) return;
    await viewModel.updateDefaultOutputLimit(value);
  }

  Future<void> _commitBraveApiKey() async {
    final value = braveApiKeyController.text.trim();
    if (value == viewModel.braveApiKey.value) return;
    await viewModel.updateBraveApiKey(value);
  }
}

/// 模型下拉：显示 `模型名 | provider`，点开 [MobileModelDialog]。
class _ModelDropdown extends StatelessWidget {
  final Map<String, List<ModelEntity>>? groupedModels;
  final ModelEntity? model;
  final void Function(String)? onChanged;
  final ProviderEntity? provider;
  const _ModelDropdown({
    this.groupedModels,
    this.model,
    this.onChanged,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final boxDecoration = BoxDecoration(
      color: colors.inputBackground.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AthenaRadius.container),
    );
    final icon = Icon(
      AthenaIcons.dropdown,
      color: colors.textInput,
      size: AthenaIcon.inlineSize,
    );
    final children = [Expanded(child: _buildText()), icon];
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
    final container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: row,
    );
    final mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showModelSelectorDialog,
      child: mouseRegion,
    );
  }

  void handleTap(ModelEntity model) {
    AthenaDialog.dismiss();
    onChanged?.call(model.id!);
  }

  void showModelSelectorDialog() {
    if (groupedModels == null || groupedModels!.isEmpty) return;
    AthenaDialog.show(
      MobileModelDialog(groupedModels: groupedModels!, onTap: handleTap),
      barrierDismissible: true,
    );
  }

  Widget _buildText() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      final textStyle = AthenaTextStyle.row.copyWith(color: colors.textInput);
      if (model == null) {
        return Text(
          'No Model',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      }
      return Text(
        '${model?.name} | ${provider?.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    });
  }
}
