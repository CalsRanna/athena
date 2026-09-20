import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class DesktopSettingAboutPage extends StatefulWidget {
  const DesktopSettingAboutPage({super.key});

  @override
  State<DesktopSettingAboutPage> createState() =>
      _DesktopSettingAboutPageState();
}

class _DesktopSettingAboutPageState extends State<DesktopSettingAboutPage> {
  String version = '';

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var textStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    var image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      height: 120,
      width: 120,
    );
    return AthenaSettingsPane(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              ClipOval(child: image),
              const SizedBox(height: 24),
              Text(version, style: textStyle),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _initState() async {
    var packageInfo = await PackageInfo.fromPlatform();
    var version = packageInfo.version;
    var buildNumber = packageInfo.buildNumber;
    setState(() {
      this.version = '$version ($buildNumber)';
    });
  }
}
