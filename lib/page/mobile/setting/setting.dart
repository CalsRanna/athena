import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var children = [
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedPowerService, size: 24),
        onTap: () => navigateProvider(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedAiBrain01, size: 24),
        onTap: () => navigateDefaultModel(context),
        title: 'Default Model',
        trailing: '',
      ),
      MobileSettingTile(
        leading: Icon(HugeIcons.strokeRoundedTools, size: 24),
        onTap: () => navigateToolList(context),
        title: 'Tool',
        trailing: '',
      ),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AScaffold(
      appBar: AAppBar(title: Text('Setting')),
      body: SingleChildScrollView(child: column),
    );
  }

  void navigateDefaultModel(BuildContext context) {
    MobileDefaultModelFormRoute().push(context);
  }

  void navigateProvider(BuildContext context) {
    MobileProviderListRoute().push(context);
  }

  void navigateToolList(BuildContext context) {
    MobileToolListRoute().push(context);
  }
}
