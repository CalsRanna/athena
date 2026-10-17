import 'package:athena_gui/page/mobile/setting/component/setting_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class MobileAboutPage extends StatefulWidget {
  const MobileAboutPage({super.key});

  @override
  State<MobileAboutPage> createState() => _MobileAboutPageState();
}

class _MobileAboutPageState extends State<MobileAboutPage> {
  static const _repository = 'https://github.com/CalsRanna/athena';

  late final viewModel = GetIt.instance<SettingViewModel>();
  String version = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleStyle = AthenaTextStyle.title.copyWith(
      color: colors.textPrimary,
    );
    final captionStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
    );
    final image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      height: 96,
      width: 96,
      filterQuality: FilterQuality.medium,
    );
    final identity = Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AthenaRadius.panel),
          child: image,
        ),
        const SizedBox(height: AthenaSpace.lg),
        Text('Athena', style: titleStyle),
        const SizedBox(height: 2),
        Text('A cross-platform AI agent workspace.', style: captionStyle),
        const SizedBox(height: AthenaSpace.sm),
        Text(version.isEmpty ? 'Loading…' : version, style: captionStyle),
      ],
    );
    final children = [
      const SizedBox(height: AthenaSpace.xxl),
      identity,
      const SizedBox(height: AthenaSpace.xxxl),
      MobileSettingTile(
        leading: const Icon(LucideIcons.code, size: AthenaIcon.largeSize),
        onTap: () => _open(_repository),
        title: 'Source code',
        subtitle: _repository.replaceFirst('https://', ''),
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(
          LucideIcons.messageCircle,
          size: AthenaIcon.largeSize,
        ),
        onTap: () => _open('$_repository/issues'),
        title: 'Report an issue',
        subtitle: 'Bugs and feature requests go to GitHub issues.',
        trailing: '',
      ),
      MobileSettingTile(
        leading: const Icon(LucideIcons.scale, size: AthenaIcon.largeSize),
        onTap: () => _open('$_repository/blob/main/LICENSE'),
        title: 'License',
        subtitle: 'MIT License',
        trailing: '',
      ),
      const SafeArea(top: false, child: SizedBox()),
    ];
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('About')),
      body: ListView(children: children),
    );
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url));
    if (!ok && mounted) AthenaDialog.error('Unable to open $url');
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    if (!mounted) return;
    setState(() {
      this.version = '$version ($buildNumber)';
    });
  }
}
