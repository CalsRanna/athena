import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopSettingAboutPage extends StatefulWidget {
  const DesktopSettingAboutPage({super.key});

  @override
  State<DesktopSettingAboutPage> createState() =>
      _DesktopSettingAboutPageState();
}

class _DesktopSettingAboutPageState extends State<DesktopSettingAboutPage> {
  late final SettingViewModel settingViewModel;
  late final ServerViewModel serverViewModel;

  String version = '';
  final developerMode = signal(false);

  @override
  void initState() {
    super.initState();
    settingViewModel = GetIt.instance<SettingViewModel>();
    serverViewModel = GetIt.instance<ServerViewModel>();
    _initState();
  }

  @override
  void dispose() {
    developerMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      height: 120,
      width: 120,
    );

    return AthenaScaffold(
      body: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openDeveloperMode,
          child: Watch((context) {
            var children = [
              ClipOval(child: image),
              SizedBox(height: 24),
              Text(version, style: textStyle),
              if (developerMode.value) const SizedBox(height: 24),
              if (developerMode.value)
                TextButton(
                  onPressed: emptyServers,
                  child: Text('Empty Servers'),
                ),
            ];
            return Column(mainAxisSize: MainAxisSize.min, children: children);
          }),
        ),
      ),
    );
  }

  void emptyServers() {
    serverViewModel.emptyServers();
  }

  void openDeveloperMode() {
    if (developerMode.value) return;

    var cancelButton = TextButton(
      onPressed: () => AthenaDialog.dismiss(),
      child: Text('Cancel'),
    );
    var openButton = TextButton(
      onPressed: () {
        AthenaDialog.dismiss();
        developerMode.value = true;
      },
      child: Text('Open'),
    );
    var alertDialog = AlertDialog(
      title: Text('Developer Mode'),
      content: Text('Are you sure you want to open developer mode?'),
      actions: [cancelButton, openButton],
    );
    showDialog(context: context, builder: (context) => alertDialog);
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
