import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 桌面端 Agent 设置。
///
/// 旧版这里是「General / Tools」二阶导航。Claude 的设置**没有第二列导航**，
/// 同一内容区里用分区标题分层（见 Claude 的 Code appearance / Appearance），
/// 所以这里改成两个分区。
@RoutePage()
class DesktopSettingAgentPage extends StatefulWidget {
  const DesktopSettingAgentPage({super.key});

  @override
  State<DesktopSettingAgentPage> createState() =>
      _DesktopSettingAgentPageState();
}

class _DesktopSettingAgentPageState extends State<DesktopSettingAgentPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();
  late final iterationsController = TextEditingController(
    text: viewModel.maxAgentIterations.value.toString(),
  );
  late final retriesController = TextEditingController(
    text: viewModel.maxRetries.value.toString(),
  );
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  late ApprovalMode approvalMode = viewModel.approvalMode.value;

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
          title: 'General',
          children: [
            _buildInputRow(
              label: 'Max Iterations',
              description: 'Maximum tool-calling rounds in a single run.',
              controller: iterationsController,
              placeholder: '100',
            ),
            _buildInputRow(
              label: 'Max Retries',
              description: 'Retries for a failed model request.',
              controller: retriesController,
              placeholder: '10',
            ),
            AthenaSettingsRow(
              label: 'Approval Mode',
              description:
                  'Who approves tool calls that need permission. Manual always '
                  'asks you; AI review lets the current model decide and asks '
                  'you when unsure; Bypass permissions runs them without '
                  'asking. Deny rules always apply. Takes effect from the '
                  'next run.',
              control: AthenaSettingsSegmented<ApprovalMode>(
                options: [
                  for (final mode in ApprovalMode.values)
                    AthenaSegmentOption(value: mode, label: mode.label),
                ],
                selected: approvalMode,
                onChanged: (value) => setState(() => approvalMode = value),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Tools',
          children: [
            _buildInputRow(
              label: 'Brave API Key',
              description:
                  'Required for web_search tool. Get a free key at '
                  'brave.com/search/api/',
              controller: braveApiKeyController,
              placeholder: 'BSA...',
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AthenaPrimaryButton(onTap: save, child: const Text('Save')),
          ],
        ),
      ],
    );
  }

  Widget _buildInputRow({
    required String label,
    required String description,
    required TextEditingController controller,
    required String placeholder,
  }) {
    return AthenaSettingsRow(
      label: label,
      description: description,
      control: SizedBox(
        width: AthenaSettings.controlColumnWidth,
        child: AthenaInput(controller: controller, placeholder: placeholder),
      ),
    );
  }

  Future<void> save() async {
    final iterations = int.tryParse(iterationsController.text.trim());
    if (iterations == null || iterations < 1) {
      AthenaDialog.warning('Max Iterations must be a valid number (minimum 1)');
      return;
    }
    final retries = int.tryParse(retriesController.text.trim());
    if (retries == null || retries < 1) {
      AthenaDialog.warning('Max Retries must be a valid number (minimum 1)');
      return;
    }
    await viewModel.updateMaxAgentIterations(iterations);
    await viewModel.updateMaxRetries(retries);
    await viewModel.updateApprovalMode(approvalMode);
    await viewModel.updateBraveApiKey(braveApiKeyController.text.trim());
    if (!mounted) return;
    AthenaDialog.success('Settings saved');
  }
}
