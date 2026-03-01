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
        onTap: () => MobileProviderListRoute().push(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(
          HugeIcons.strokeRoundedArtificialIntelligence03,
          size: 24,
        ),
        onTap: () => MobileSentinelListRoute().push(context),
        title: 'Sentinel',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedTools, size: 24),
        onTap: () => MobileToolListRoute().push(context),
        title: 'Built-in Tools',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedAiBrain01, size: 24),
        onTap: () => MobileDefaultModelFormRoute().push(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedDatabase, size: 24),
        onTap: () => MobileDataRoute().push(context),
        title: 'Data',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedInformationCircle, size: 24),
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
}
