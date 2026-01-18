import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedPowerService, size: 24),
        onTap: () => navigateProvider(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(
          HugeIcons.strokeRoundedArtificialIntelligence03,
          size: 24,
        ),
        onTap: () => navigateSentinel(context),
        title: 'Sentinel',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedTools, size: 24),
        onTap: () => navigateToolList(context),
        title: 'Built-in Tools',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedAiBrain01, size: 24),
        onTap: () => navigateDefaultModel(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedInformationCircle, size: 24),
        onTap: () => navigateAbout(context),
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

  void navigateAbout(BuildContext context) {
    MobileAboutRoute().push(context);
  }

  void navigateDefaultModel(BuildContext context) {
    MobileDefaultModelFormRoute().push(context);
  }

  void navigateProvider(BuildContext context) {
    MobileProviderListRoute().push(context);
  }

  void navigateSentinel(BuildContext context) {
    MobileSentinelListRoute().push(context);
  }

  void navigateToolList(BuildContext context) {
    MobileToolListRoute().push(context);
  }
}
