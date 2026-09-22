import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 桌面端 About：应用标识 + 版本，下面是几条可点的资源行。
///
/// 旧版只有一个大图标和版本号。Claude 的 About 也很短，但每一行都有用
/// （版本、更新、许可）；这里给的是仓库、问题反馈、许可证三条外链，
/// 版本行可以一键复制到剪贴板。
@RoutePage()
class DesktopSettingAboutPage extends StatefulWidget {
  const DesktopSettingAboutPage({super.key});

  @override
  State<DesktopSettingAboutPage> createState() =>
      _DesktopSettingAboutPageState();
}

class _DesktopSettingAboutPageState extends State<DesktopSettingAboutPage> {
  static const _repository = 'https://github.com/CalsRanna/athena';

  String version = '';
  String buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var nameStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.headingFontSize,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    var taglineStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var mark = ClipRRect(
      borderRadius: BorderRadius.circular(AthenaRadius.container),
      child: Image.asset(
        'asset/image/launcher_icon_ios_512x512.jpg',
        height: 48,
        width: 48,
        filterQuality: FilterQuality.medium,
      ),
    );
    var identity = Row(
      children: [
        mark,
        const SizedBox(width: AthenaSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Athena', style: nameStyle),
              const SizedBox(height: 2),
              Text(
                'A cross-platform AI agent workspace.',
                style: taglineStyle,
              ),
            ],
          ),
        ),
      ],
    );
    var versionLabel = version.isEmpty
        ? 'Loading…'
        : buildNumber.isEmpty
        ? version
        : '$version ($buildNumber)';
    return AthenaSettingsPane(
      children: [
        AthenaSettingsInset(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
          child: identity,
        ),
        AthenaSettingsSection(
          first: true,
          title: 'About',
          children: [
            AthenaSettingsRow(
              label: 'Version',
              description: versionLabel,
              control: AthenaSecondaryButton.small(
                onTap: version.isEmpty ? null : _copyVersion,
                child: const Text('Copy'),
              ),
            ),
            AthenaSettingsRow(
              label: 'Source code',
              description: _repository.replaceFirst('https://', ''),
              chevron: true,
              onTap: () => _open(_repository),
            ),
            AthenaSettingsRow(
              label: 'Report an issue',
              description: 'Bugs and feature requests go to GitHub issues.',
              chevron: true,
              onTap: () => _open('$_repository/issues'),
            ),
            AthenaSettingsRow(
              label: 'License',
              description: 'MIT License',
              chevron: true,
              onTap: () => _open('$_repository/blob/main/LICENSE'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadVersion() async {
    var packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _copyVersion() async {
    await Clipboard.setData(
      ClipboardData(text: 'Athena $version ($buildNumber)'),
    );
    if (mounted) AthenaDialog.success('Version copied');
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url));
    if (!ok && mounted) AthenaDialog.error('Unable to open $url');
  }
}
