import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      MobileSettingTile(
        leading: Icon(LucideIcons.botMessageSquare, size: 24),
        onTap: () => MobileAgentRoute().push(context),
        title: 'Agent',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(LucideIcons.plug, size: 24),
        onTap: () => MobileProviderListRoute().push(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(
          LucideIcons.bot,
          size: 24,
        ),
        onTap: () => MobileSentinelListRoute().push(context),
        title: 'Sentinel',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(LucideIcons.bookOpen, size: 24),
        onTap: () => MobileSkillListRoute().push(context),
        title: 'Skills',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(LucideIcons.brain, size: 24),
        onTap: () => MobileExperienceListRoute().push(context),
        title: 'Experiences',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(LucideIcons.cpu, size: 24),
        onTap: () => MobileDefaultModelFormRoute().push(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(LucideIcons.database, size: 24),
        onTap: () => MobileDataRoute().push(context),
        title: 'Data',
        trailing: '',
      ),
      Watch((context) {
        final mode = GetIt.instance<SettingViewModel>().themeMode.value;
        return MobileSettingTile(
          leading: Icon(LucideIcons.moon, size: 24),
          onTap: () => _showAppearanceSheet(context),
          title: 'Appearance',
          trailing: _themeModeLabel(mode),
        );
      }),
      MobileSettingTile(
        leading: Icon(LucideIcons.info, size: 24),
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

  /// 外观选择：bottom sheet 内使用行列表，主题与字号各一组，
  /// 样式与其他移动端选择弹窗一致。
  void _showAppearanceSheet(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final viewModel = GetIt.instance<SettingViewModel>();
    AthenaDialog.show(
      ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          _sheetLabel('Theme', colors),
          _appearanceTile(viewModel, ThemeMode.dark, 'Dark'),
          _appearanceTile(viewModel, ThemeMode.light, 'Light'),
          _appearanceTile(viewModel, ThemeMode.system, 'System'),
          const SizedBox(height: 12),
          _sheetLabel('Font size', colors),
          for (final size in AthenaTextSize.values) _textSizeTile(viewModel, size),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text, AthenaColors colors) {
    var textStyle = AthenaTextStyle.caption.copyWith(color: colors.textSecondary, height: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(text, style: textStyle),
    );
  }

  Widget _textSizeTile(SettingViewModel viewModel, AthenaTextSize size) {
    return AthenaBottomSheetTile(
      selected: viewModel.textSize.value == size,
      onTap: () {
        viewModel.setTextSize(size);
        AthenaDialog.dismiss();
      },
      title: '${size.label} text',
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
