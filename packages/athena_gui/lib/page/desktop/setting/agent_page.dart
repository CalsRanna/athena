import 'package:athena_gui/page/desktop/setting/component/model_menu.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Agent 设置：默认模型、请求设置与工具。
///
/// 每一行**改了即存**，没有页面级 Save：模型下拉与分段控件点选即生效；
/// 数字与密钥输入在失焦或回车时提交，非法值就地报错并回退。
@RoutePage()
class DesktopSettingAgentPage extends StatefulWidget {
  const DesktopSettingAgentPage({super.key});

  @override
  State<DesktopSettingAgentPage> createState() =>
      _DesktopSettingAgentPageState();
}

class _DesktopSettingAgentPageState extends State<DesktopSettingAgentPage> {
  final viewModel = GetIt.instance<SettingViewModel>();
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
    return AthenaSettingsPane(
      children: [
        SignalBuilder(
          builder: (context) {
            final hasModels =
                modelViewModel.groupedEnabledModels.value.isNotEmpty;
            return AthenaSettingsSection(
              first: true,
              title: 'Default models',
              description:
                  'The model each job starts with. You can still switch models '
                  'inside a session.',
              children: [
                if (!hasModels)
                  const AthenaSettingsEmptyState(
                    icon: LucideIcons.cpu,
                    title: 'No enabled models',
                    hint:
                        'Enable a provider and add an API key to pick default '
                        'models.',
                  ),
                if (hasModels) ...[
                  AthenaSettingsRow(
                    label: 'Session model',
                    description:
                        'The model new sessions and the agent loop start with.',
                    control: _buildModelSelect(
                      viewModel.chatModelId.value,
                      viewModel.updateChatModelId,
                    ),
                  ),
                  AthenaSettingsRow(
                    label: 'Session naming model',
                    description:
                        'Names a session after its first exchange. Falls back to '
                        'the session model.',
                    control: _buildModelSelect(
                      viewModel.chatNamingModelId.value,
                      viewModel.updateChatNamingModelId,
                      clearable: true,
                    ),
                  ),
                  AthenaSettingsRow(
                    label: 'Sentinel metadata model',
                    description:
                        'Generates a Sentinel\'s name, description '
                        'and tags from its system prompt.',
                    control: _buildModelSelect(
                      viewModel.sentinelMetadataGenerationModelId.value,
                      viewModel.updateSentinelMetadataGenerationModelId,
                      clearable: true,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        AthenaSettingsSection(
          title: 'Model requests',
          children: [
            AthenaSettingsRow(
              label: 'Max attempts',
              description:
                  'Total tries for a model request that fails on the network, '
                  'including the first attempt.',
              error: retriesError,
              control: _buildNumberField(
                controller: retriesController,
                placeholder: '10',
                onCommit: _commitRetries,
              ),
            ),
            AthenaSettingsRow(
              label: 'Default output limit',
              description:
                  'Output token limit for models without their own limit. '
                  'Applies only to the Messages API format.',
              error: outputLimitError,
              control: SizedBox(
                width: AthenaSettingsControlWidth.narrow,
                child: AthenaSettingsTextField(
                  controller: outputLimitController,
                  placeholder: '128000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onBlur: _commitOutputLimit,
                  onSubmitted: (_) => _commitOutputLimit(),
                ),
              ),
            ),
            AthenaSettingsRow(
              label: 'Default reasoning effort',
              description:
                  'Reasoning effort new sessions start with. You can still '
                  'change it in the composer.',
              control: SignalBuilder(
                builder: (context) {
                  return AthenaSettingsSegmented<String>(
                    selected: viewModel.defaultReasoningEffort.value,
                    onChanged: viewModel.updateDefaultReasoningEffort,
                    options: [
                      for (final option in reasoningEffortOptions)
                        AthenaSegmentOption(value: option.$1, label: option.$2),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Tools',
          children: [
            SignalBuilder(
              builder: (context) {
                return AthenaSettingsRow(
                  label: 'Background task reports',
                  description:
                      'When a background command finishes, start a run that '
                      'reads its output and reports back. That run uses this '
                      'session\'s model, so it costs a request; it only has '
                      'read-only tools and never asks for approval.',
                  control: AthenaSwitch(
                    value: viewModel.backgroundTaskReports.value,
                    onChanged: (value) =>
                        viewModel.updateBackgroundTaskReports(value),
                  ),
                );
              },
            ),
            AthenaSettingsRow(
              label: 'Brave Search API key',
              description:
                  'Used by web_search. Get a free key at '
                  'brave.com/search/api.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: braveApiKeyController,
                  placeholder: 'BSA…',
                  obscure: true,
                  onBlur: _commitBraveApiKey,
                  onSubmitted: (_) => _commitBraveApiKey(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelSelect(
    String modelId,
    Future<void> Function(String) onChanged, {
    bool clearable = false,
  }) {
    return SizedBox(
      width: AthenaSettingsControlWidth.wide,
      child: DesktopSettingModelSelector(
        modelId: modelId,
        clearable: clearable,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onCommit,
  }) {
    return SizedBox(
      width: AthenaSettingsControlWidth.narrow,
      child: AthenaSettingsTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onBlur: onCommit,
        onSubmitted: (_) => onCommit(),
      ),
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
