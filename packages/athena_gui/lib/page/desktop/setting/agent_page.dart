import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Agent 设置。
///
/// 每一行**改了即存**，没有页面级 Save：分段控件点选即生效；数字与密钥
/// 输入在失焦或回车时提交，非法值就地报错并回退。与 Claude 的设置一致，
/// 也与本面板里的其他分区（Default models / General）一致。
@RoutePage()
class DesktopSettingAgentPage extends StatefulWidget {
  const DesktopSettingAgentPage({super.key});

  @override
  State<DesktopSettingAgentPage> createState() =>
      _DesktopSettingAgentPageState();
}

class _DesktopSettingAgentPageState extends State<DesktopSettingAgentPage> {
  final viewModel = GetIt.instance<SettingViewModel>();
  late final iterationsController = TextEditingController(
    text: viewModel.maxAgentIterations.value.toString(),
  );
  late final retriesController = TextEditingController(
    text: viewModel.maxRetries.value.toString(),
  );
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  String? iterationsError;
  String? retriesError;

  @override
  void dispose() {
    iterationsController.dispose();
    retriesController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Permissions',
          children: [
            Watch((context) {
              return AthenaSettingsRow(
                label: 'Approval mode',
                description:
                    'Who approves tool calls that need permission. Deny '
                    'rules always apply. Takes effect from the next run.',
                control: AthenaSettingsSegmented<ApprovalMode>(
                  options: [
                    for (final mode in ApprovalMode.values)
                      AthenaSegmentOption(value: mode, label: mode.label),
                  ],
                  selected: viewModel.approvalMode.value,
                  onChanged: viewModel.updateApprovalMode,
                ),
              );
            }),
            Watch((context) {
              final mode = viewModel.approvalMode.value;
              return AthenaSettingsRow(
                label: mode.label,
                description: mode.description,
                leading: const _Marker(),
              );
            }),
          ],
        ),
        AthenaSettingsSection(
          title: 'Limits',
          children: [
            AthenaSettingsRow(
              label: 'Max iterations',
              description:
                  'Tool-calling rounds a single run may take before it '
                  'stops.',
              error: iterationsError,
              control: _buildNumberField(
                controller: iterationsController,
                placeholder: '100',
                onCommit: _commitIterations,
              ),
            ),
            AthenaSettingsRow(
              label: 'Max retries',
              description:
                  'Attempts for a model request that fails on the network.',
              error: retriesError,
              control: _buildNumberField(
                controller: retriesController,
                placeholder: '10',
                onCommit: _commitRetries,
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Tools',
          children: [
            AthenaSettingsRow(
              label: 'Brave Search API key',
              description:
                  'Required by the web_search tool. Get a free key at '
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

  Widget _buildNumberField({
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onCommit,
  }) {
    return SizedBox(
      width: AthenaSettings.controlNarrowWidth,
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

  Future<void> _commitIterations() async {
    final value = int.tryParse(iterationsController.text.trim());
    if (value == null || value < 1) {
      setState(() => iterationsError = 'Enter a whole number of at least 1.');
      return;
    }
    setState(() => iterationsError = null);
    if (value == viewModel.maxAgentIterations.value) return;
    await viewModel.updateMaxAgentIterations(value);
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

  Future<void> _commitBraveApiKey() async {
    final value = braveApiKeyController.text.trim();
    if (value == viewModel.braveApiKey.value) return;
    await viewModel.updateBraveApiKey(value);
  }
}

/// 「当前生效」那一行标签前的小点。
class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) {
    return AthenaSettingsDot(color: Theme.of(context).colorScheme.primary);
  }
}
