import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:athena_gui/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedAiSetting, size: 24),
        onTap: () => MobileAgentRoute().push(context),
        title: 'Agent',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedPowerService, size: 24),
        onTap: () => MobileProviderListRoute().push(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(
          HugeIcons.strokeRoundedArtificialIntelligence03,
          size: 24,
        ),
        onTap: () => MobileSentinelListRoute().push(context),
        title: 'Sentinel',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedAiBrain01, size: 24),
        onTap: () => MobileDefaultModelFormRoute().push(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedDatabase, size: 24),
        onTap: () => MobileDataRoute().push(context),
        title: 'Data',
        trailing: '',
      ),
      Watch((context) {
        final mode = GetIt.instance<SettingViewModel>().themeMode.value;
        return MobileSettingTile(
          leading: Icon(HugeIcons.strokeRoundedMoon01, size: 24),
          onTap: () => _showAppearanceSheet(context),
          title: 'Appearance',
          trailing: _themeModeLabel(mode),
        );
      }),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedInformationCircle, size: 24),
        onTap: () => MobileAboutRoute().push(context),
        title: 'About Athena',
        trailing: '',
      ),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Setting')),
      body: SingleChildScrollView(child: column),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'Dark',
      ThemeMode.light => 'Light',
      ThemeMode.system => 'System',
    };
  }

  /// 外观选择：bottom sheet 内使用 Athena Tag 三选一。
  void _showAppearanceSheet(BuildContext context) {
    final viewModel = GetIt.instance<SettingViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    AthenaDialog.show(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: titleStyle),
          const SizedBox(height: 16),
          Watch((context) {
            final mode = viewModel.themeMode.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AthenaTagButton(
                  selected: mode == ThemeMode.dark,
                  onTap: () {
                    viewModel.setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                  child: Text('Dark'),
                ),
                AthenaTagButton(
                  selected: mode == ThemeMode.light,
                  onTap: () {
                    viewModel.setThemeMode(ThemeMode.light);
                    Navigator.of(context).pop();
                  },
                  child: Text('Light'),
                ),
                AthenaTagButton(
                  selected: mode == ThemeMode.system,
                  onTap: () {
                    viewModel.setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                  child: Text('System'),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
