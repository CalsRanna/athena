import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Agent 设置。
///
/// 每一行**改了即存**，没有页面级 Save：分段控件点选即生效；数字与密钥
/// 输入在失焦或回车时提交，非法值就地报错并回退。与设置页的其余行一致，
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
        AthenaSettingsSection(
          first: true,
          title: 'Limits',
          children: [
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
            AthenaSettingsRow(
              label: 'Default output limit',
              description:
                  'Output token limit for models without their own limit set. '
                  'Applies to the Messages protocol only.',
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
          ],
        ),
        AthenaSettingsSection(
          title: 'Tools',
          children: [
            Watch((context) {
              return AthenaSettingsRow(
                label: 'Report finished background tasks',
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
            }),
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
