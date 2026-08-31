import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
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

  /// 外观选择：bottom sheet 内使用行列表三选一,样式与其他移动端
  /// 选择弹窗一致。
  void _showAppearanceSheet(BuildContext context) {
    final viewModel = GetIt.instance<SettingViewModel>();
    AthenaDialog.show(
      ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          _appearanceTile(viewModel, ThemeMode.dark, 'Dark'),
          _appearanceTile(viewModel, ThemeMode.light, 'Light'),
          _appearanceTile(viewModel, ThemeMode.system, 'System'),
        ],
      ),
    );
  }

  Widget _appearanceTile(
    SettingViewModel viewModel,
    ThemeMode mode,
    String label,
  ) {
    return AthenaBottomSheetTile(
      selected: viewModel.themeMode.value == mode,
      onTap: () {
        viewModel.setThemeMode(mode);
        AthenaDialog.dismiss();
      },
      title: label,
    );
  }
}
