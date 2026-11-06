import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
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
    final colors = context.athenaColors;
    return AthenaSettingsPane(
      title: 'Appearance',
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Theme',
          description: 'System follows the appearance selected on this device.',
          children: [
            AthenaSettingsInset(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SignalBuilder(
                  builder: (context) =>
                      AthenaSettingsSegmented<AthenaThemeMode>(
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
                      ),
                ),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Conversation text size',
          children: [
            AthenaSettingsInset(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SignalBuilder(
                  builder: (context) => AthenaSettingsSegmented<AthenaTextSize>(
                    selected: viewModel.textSize.value,
                    onChanged: viewModel.setTextSize,
                    options: [
                      for (final option in AthenaTextSize.values)
                        AthenaSegmentOption(value: option, label: option.label),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AthenaSpace.xl),
        AthenaSettingsInset(
          child: Container(
            padding: const EdgeInsets.all(AthenaSpace.lg),
            decoration: BoxDecoration(
              color: colors.surfacePanel,
              borderRadius: BorderRadius.circular(AthenaRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversation preview',
                  style: AthenaTextStyle.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AthenaSpace.xs),
                SignalBuilder(
                  builder: (context) => Text(
                    'How can I help with your project?',
                    style: viewModel.textSize.value.prose.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
