import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class MobileAboutPage extends StatefulWidget {
  const MobileAboutPage({super.key});

  @override
  State<MobileAboutPage> createState() => _MobilAboutPageState();
}

class _MobilAboutPageState extends State<MobileAboutPage> {
  late final viewModel = GetIt.instance<SettingViewModel>();
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
    var children = [
      ClipOval(child: image),
      SizedBox(height: 24),
      Text(version, style: textStyle),
    ];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    return AthenaScaffold(
      appBar: AthenaAppBar(title: const Text('About')),
      body: Center(child: column),
    );
  }

  @override
  void initState() {
    super.initState();
    _initState();
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
