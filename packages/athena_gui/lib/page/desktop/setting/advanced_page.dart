import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildListView(context),
        Expanded(child: _buildContentView(context)),
      ],
    );
  }

  Widget _buildListView(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    const items = ['Appearance', 'Data'];
    final borderSide = BorderSide(
      color: colors.borderFaint.withValues(alpha: 0.2),
    );
    return Container(
      width: 240,
      decoration: BoxDecoration(border: Border(right: borderSide)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, itemIndex) => DesktopMenuTile(
          active: index == itemIndex,
          label: items[itemIndex],
          onTap: () => setState(() => index = itemIndex),
        ),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildContentView(BuildContext context) {
    return switch (index) {
      0 => _buildAppearanceView(context),
      1 => _buildDataView(context),
      _ => const SizedBox(),
    };
  }

  Widget _buildAppearanceView(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: [
        Text('Appearance', style: _titleStyle(colors)),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(
              width: 120,
              child: AthenaFormTileLabel(title: 'Theme'),
            ),
            Expanded(
              child: Watch((context) {
                final mode = viewModel.themeMode.value;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ThemeButton(
                      key: const ValueKey('theme-mode-dark'),
                      icon: HugeIcons.strokeRoundedMoon01,
                      label: 'Dark',
                      selected: mode == ThemeMode.dark,
                      onTap: () => viewModel.setThemeMode(ThemeMode.dark),
                    ),
                    _ThemeButton(
                      key: const ValueKey('theme-mode-light'),
                      icon: HugeIcons.strokeRoundedSun02,
                      label: 'Light',
                      selected: mode == ThemeMode.light,
                      onTap: () => viewModel.setThemeMode(ThemeMode.light),
                    ),
                    _ThemeButton(
                      key: const ValueKey('theme-mode-system'),
                      icon: HugeIcons.strokeRoundedComputer,
                      label: 'System',
                      selected: mode == ThemeMode.system,
                      onTap: () => viewModel.setThemeMode(ThemeMode.system),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 120),
          child: Text(
            'System follows the appearance selected on this device.',
            style: _tipStyle(colors),
          ),
        ),
      ],
    );
  }

  Widget _buildDataView(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: [
        Text('Data', style: _titleStyle(colors)),
        const SizedBox(height: 12),
        _DataActionTile(
          icon: HugeIcons.strokeRoundedFileExport,
          title: 'Export configuration',
          description:
              'Save providers, models, and Sentinels as a JSON backup.',
          actionIcon: HugeIcons.strokeRoundedArrowUpRight02,
          actionLabel: 'Export',
          onTap: _handleExport,
        ),
        const SizedBox(height: 12),
        _DataActionTile(
          icon: HugeIcons.strokeRoundedFileImport,
          title: 'Import configuration',
          description:
              'Restore a JSON backup and replace current providers and models.',
          actionIcon: HugeIcons.strokeRoundedArrowDownLeft02,
          actionLabel: 'Import',
          onTap: _handleImport,
        ),
        const SizedBox(height: 24),
        Text(
          'Danger Zone',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Actions here affect all local application data.',
          style: _tipStyle(colors),
        ),
        const SizedBox(height: 12),
        _DataActionTile(
          icon: HugeIcons.strokeRoundedDatabaseRestore,
          title: 'Reset Athena',
          description:
              'Delete all local data and restore every setting to its default.',
          actionIcon: HugeIcons.strokeRoundedDelete02,
          actionLabel: 'Reset',
          onTap: _handleReset,
          danger: true,
        ),
      ],
    );
  }

  TextStyle _titleStyle(AthenaColors colors) {
    return TextStyle(
      color: colors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _tipStyle(AthenaColors colors) {
    return TextStyle(
      color: colors.border,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
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

class _ThemeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _ThemeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AthenaTagButton(
      selected: selected,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

class _DataActionTile extends StatelessWidget {
  final IconData actionIcon;
  final String actionLabel;
  final bool danger;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final String title;

  const _DataActionTile({
    required this.actionIcon,
    required this.actionLabel,
    this.danger = false,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final accentColor = danger ? colors.statusError : colors.iconSecondary;
    return Container(
      decoration: BoxDecoration(
        color: danger
            ? colors.statusError.withValues(alpha: 0.055)
            : colors.inputBackground.withValues(alpha: 0.6),
        border: danger
            ? Border.all(color: colors.statusError.withValues(alpha: 0.24))
            : null,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.iconSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AthenaSecondaryButton.small(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon, color: accentColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  actionLabel,
                  style: danger ? TextStyle(color: accentColor) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
