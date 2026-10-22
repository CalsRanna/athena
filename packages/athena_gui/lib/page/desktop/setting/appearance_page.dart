import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Appearance：主题与字号。
@RoutePage()
class DesktopSettingAppearancePage extends StatefulWidget {
  const DesktopSettingAppearancePage({super.key});

  @override
  State<DesktopSettingAppearancePage> createState() =>
      _DesktopSettingAppearancePageState();
}

class _DesktopSettingAppearancePageState
    extends State<DesktopSettingAppearancePage> {
  final viewModel = GetIt.instance<SettingViewModel>();

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
                return AthenaSettingsSegmented<AthenaThemeMode>(
                  selected: viewModel.themeMode.value,
                  onChanged: viewModel.setThemeMode,
                  options: const [
                    AthenaSegmentOption(
                      value: AthenaThemeMode.light,
                      label: 'Light',
                    ),
                    AthenaSegmentOption(
                      value: AthenaThemeMode.dark,
                      label: 'Dark',
                    ),
                    AthenaSegmentOption(
                      value: AthenaThemeMode.system,
                      label: 'System',
                    ),
                  ],
                );
              }),
            ),
            AthenaSettingsRow(
              label: 'Text size',
              description: 'Applies to message text and code in conversations.',
              control: Watch((context) {
                return AthenaSettingsSegmented<AthenaTextSize>(
                  selected: viewModel.textSize.value,
                  onChanged: viewModel.setTextSize,
                  options: [
                    for (final option in AthenaTextSize.values)
                      AthenaSegmentOption(value: option, label: option.label),
                  ],
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
