import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
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
    final children = [
      MobileSettingTile(
        leading: const Icon(LucideIcons.workflow, size: AthenaIcon.largeSize),
        onTap: () => const MobileAgentRoute().push<void>(context),
        title: 'Agent',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(AthenaIcons.connection, size: AthenaIcon.largeSize),
        onTap: () => const MobileProviderListRoute().push<void>(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.userRound, size: AthenaIcon.largeSize),
        onTap: () => const MobileSentinelListRoute().push<void>(context),
        title: 'Sentinel',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.bookOpen, size: AthenaIcon.largeSize),
        onTap: () => const MobileSkillListRoute().push<void>(context),
        title: 'Skills',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.brain, size: AthenaIcon.largeSize),
        onTap: () => const MobileExperienceListRoute().push<void>(context),
        title: 'Experiences',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.cpu, size: AthenaIcon.largeSize),
        onTap: () => const MobileDefaultModelFormRoute().push<void>(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.database, size: AthenaIcon.largeSize),
        onTap: () => const MobileDataRoute().push<void>(context),
        title: 'Data',
        trailing: '',
      ),
      Watch((context) {
        final mode = GetIt.instance<SettingViewModel>().themeMode.value;
        return MobileSettingTile(
          leading: const Icon(LucideIcons.moon, size: AthenaIcon.largeSize),
          onTap: () => _showAppearanceSheet(context),
          title: 'Appearance',
          trailing: _themeModeLabel(mode),
        );
      }),
      MobileSettingTile(
        leading: const Icon(LucideIcons.info, size: AthenaIcon.largeSize),
        onTap: () => const MobileAboutRoute().push<void>(context),
        title: 'About Athena',
        trailing: '',
      ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('Setting')),
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
          _sheetLabel('Session text size', colors),
          for (final size in AthenaTextSize.values)
            _textSizeTile(viewModel, size),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text, AthenaColors colors) {
    final textStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
    );
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
