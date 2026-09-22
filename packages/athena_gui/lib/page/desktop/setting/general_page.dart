import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 桌面端 General（应用本身的设置）：Appearance / Data / Danger zone。
///
/// 对应 Claude 设置里 `Desktop app → General`。旧名 Advanced 不准确——
/// 这里放的是主题、字号、备份这些最常用的项，不是「高级」选项。
@RoutePage()
class DesktopSettingGeneralPage extends StatefulWidget {
  const DesktopSettingGeneralPage({super.key});

  @override
  State<DesktopSettingGeneralPage> createState() =>
      _DesktopSettingGeneralPageState();
}

class _DesktopSettingGeneralPageState extends State<DesktopSettingGeneralPage> {
  final viewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final dataDirectory = GetIt.instance<FileStorage>().root.path;
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Appearance',
          children: [
            AthenaSettingsRow(
              label: 'Theme',
              description: 'System follows the appearance selected on this device.',
              control: Watch((context) {
                return AthenaSettingsSegmented<ThemeMode>(
                  selected: viewModel.themeMode.value,
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
            AthenaSettingsRow(
              label: 'Text size',
              description: 'Applies to the interface, conversations and code.',
              control: Watch((context) {
                return AthenaSettingsSegmented<AthenaTextSize>(
                  selected: viewModel.textSize.value,
                  onChanged: viewModel.setTextSize,
                  options: [
                    for (final option in AthenaTextSize.values)
                      AthenaSegmentOption(
                        value: option,
                        label: option.label,
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
              label: 'Data folder',
              description: dataDirectory,
              control: AthenaSecondaryButton.small(
                onTap: () => _openFolder(dataDirectory),
                child: const Text('Show in Finder'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Export configuration',
              description:
                  'Save providers, models and Sentinels as a JSON backup.',
              control: AthenaSecondaryButton.small(
                onTap: _handleExport,
                child: const Text('Export…'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Import configuration',
              description:
                  'Restore a JSON backup. Replaces current providers and '
                  'models.',
              control: AthenaSecondaryButton.small(
                onTap: _handleImport,
                child: const Text('Import…'),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Danger zone',
          children: [
            AthenaSettingsRow(
              label: 'Reset Athena',
              description:
                  'Deletes every chat, provider, model and Sentinel on this '
                  'device and restores all settings to their defaults.',
              control: AthenaSecondaryButton.small(
                onTap: _handleReset,
                child: Text(
                  'Reset…',
                  style: TextStyle(color: colors.dangerText),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openFolder(String path) async {
    final ok = await launchUrl(Uri.directory(path));
    if (!ok && mounted) AthenaDialog.error('Unable to open $path');
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
