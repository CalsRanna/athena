import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings_panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Advanced 设置。
///
/// 旧版这里是「Appearance / Data」二阶导航，现在是同一内容区的两个分区 +
/// 一个 Danger Zone 分区（Claude 的设置也是这种「一个导航项对应多个分区」）。
/// 主题选择改用 Claude 的**分段控件**（Claude 的 Appearance 分区正是分段控件）。
@RoutePage()
class DesktopSettingAdvancedPage extends StatefulWidget {
  const DesktopSettingAdvancedPage({super.key});

  @override
  State<DesktopSettingAdvancedPage> createState() =>
      _DesktopSettingAdvancedPageState();
}

class _DesktopSettingAdvancedPageState
    extends State<DesktopSettingAdvancedPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Appearance',
          children: [
            AthenaSettingsRow(
              label: 'Theme',
              description:
                  'System follows the appearance selected on this device.',
              control: Watch((context) {
                var mode = viewModel.themeMode.value;
                return AthenaSettingsSegmented<ThemeMode>(
                  selected: mode,
                  onChanged: viewModel.setThemeMode,
                  options: const [
                    AthenaSegmentOption(value: ThemeMode.light, label: 'Light'),
                    AthenaSegmentOption(value: ThemeMode.dark, label: 'Dark'),
                    AthenaSegmentOption(
                      value: ThemeMode.system,
                      label: 'System',
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Data',
          children: [
            AthenaSettingsRow(
              label: 'Export configuration',
              description:
                  'Save providers, models, and Sentinels as a JSON backup.',
              control: AthenaSecondaryButton.small(
                onTap: _handleExport,
                child: const Text('Export'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Import configuration',
              description:
                  'Restore a JSON backup and replace current providers and '
                  'models.',
              control: AthenaSecondaryButton.small(
                onTap: _handleImport,
                child: const Text('Import'),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Danger Zone',
          children: [
            AthenaSettingsRow(
              label: 'Reset Athena',
              description:
                  'Delete all local data and restore every setting to its '
                  'default.',
              control: _buildResetButton(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(color: colors.dangerText);
    return AthenaSecondaryButton.small(
      onTap: _handleReset,
      child: Text('Reset', style: textStyle),
    );
  }

  Future<void> _handleExport() {
    return _runDataOperation(
      action: viewModel.exportData,
      successMessage: 'Configuration exported',
      cancelledMessage: 'Export cancelled',
      failureMessage: 'Unable to export configuration',
    );
  }

  Future<void> _handleImport() async {
    final confirmed = await AthenaDialog.confirm(
      'Importing a backup replaces your current providers and models. Continue?',
    );
    if (!mounted || confirmed != true) return;
    await _runDataOperation(
      action: viewModel.importData,
      successMessage: 'Configuration imported',
      cancelledMessage: 'Import cancelled',
      failureMessage: 'Unable to import configuration',
    );
  }

  Future<void> _handleReset() async {
    final confirmed = await AthenaDialog.confirm(
      'Reset Athena and permanently delete all local data and settings?',
      dismissible: false,
    );
    if (!mounted || confirmed != true) return;
    await _runDataOperation(
      action: viewModel.resetData,
      successMessage: 'Athena has been reset',
      cancelledMessage: 'Reset cancelled',
      failureMessage: 'Unable to reset Athena',
    );
  }

  Future<void> _runDataOperation({
    required Future<bool> Function() action,
    required String successMessage,
    required String cancelledMessage,
    required String failureMessage,
  }) async {
    bool? success;
    var failed = false;
    AthenaDialog.loading();
    try {
      success = await action();
    } catch (_) {
      failed = true;
    } finally {
      AthenaDialog.dismiss();
    }
    if (!mounted) return;
    if (failed) {
      AthenaDialog.error(failureMessage);
    } else if (success == true) {
      AthenaDialog.success(successMessage);
    } else {
      AthenaDialog.info(cancelledMessage);
    }
  }
}
