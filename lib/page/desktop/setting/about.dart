import 'package:athena/provider/setting.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server.dart';
import 'package:athena/view_model/setting.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class DesktopSettingAboutPage extends ConsumerStatefulWidget {
  const DesktopSettingAboutPage({super.key});

  @override
  ConsumerState<DesktopSettingAboutPage> createState() =>
      _DesktopSettingAboutPageState();
}

class _DesktopSettingAboutPageState
    extends ConsumerState<DesktopSettingAboutPage> {
  late final viewModel = SettingViewModel(ref);
  String version = '';

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
    var developerMode = ref.watch(developerModeNotifierProvider);
    var children = [
      ClipOval(child: image),
      SizedBox(height: 24),
      Text(version, style: textStyle),
      if (developerMode) const SizedBox(height: 24),
      if (developerMode)
        TextButton(onPressed: emptyServers, child: Text('Empty Servers')),
    ];
    var column = Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openDeveloperMode,
      child: column,
    );
    return AthenaScaffold(body: Center(child: gestureDetector));
  }

  void emptyServers() {
    ServerViewModel(ref).emptyServers();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void openDeveloperMode() {
    var developerMode = ref.read(developerModeNotifierProvider);
    if (developerMode) return;
    var cancelButton = TextButton(
      onPressed: () => AthenaDialog.dismiss(),
      child: Text('Cancel'),
    );
    var openButton = TextButton(
      onPressed: () {
        AthenaDialog.dismiss();
        viewModel.openDeveloperMode();
      },
      child: Text('Open'),
    );
    var alertDialog = AlertDialog(
      title: Text('Developer Mode'),
      content: Text('Are you sure you want to open developer mode?'),
      actions: [cancelButton, openButton],
    );
    showDialog(
      context: context,
      builder: (context) => alertDialog,
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
