import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/button.dart';
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
                AthenaSecondaryButton.small(
                  onTap: emptyServers,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Empty Servers'),
                  ),
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
    AthenaDialog.show(const _DesktopDeveloperModeDialog());
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

class _DesktopDeveloperModeDialog extends StatelessWidget {
  const _DesktopDeveloperModeDialog();

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    final messageStyle = TextStyle(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.8),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final children = [
      Text('Developer Mode', style: titleStyle),
      const SizedBox(height: 12),
      Text(
        'Are you sure you want to open developer mode?',
        style: messageStyle,
      ),
      const SizedBox(height: 24),
      _buildButtons(context),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    final boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    final container = Container(
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 520),
      decoration: boxDecoration,
      padding: const EdgeInsets.all(32),
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  Widget _buildButtons(BuildContext context) {
    final state = context.findAncestorStateOfType<_DesktopSettingAboutPageState>();
    final edgeInsets = const EdgeInsets.symmetric(horizontal: 16);
    final cancelButton = AthenaSecondaryButton(
      onTap: AthenaDialog.dismiss,
      child: Padding(padding: edgeInsets, child: const Text('Cancel')),
    );
    final openButton = AthenaPrimaryButton(
      onTap: () {
        AthenaDialog.dismiss();
        state?.developerMode.value = true;
      },
      child: Padding(padding: edgeInsets, child: const Text('Open')),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [cancelButton, const SizedBox(width: 12), openButton],
    );
  }
}
