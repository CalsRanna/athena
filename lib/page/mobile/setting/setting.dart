import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var children = [
      MobileSettingTile(
        onTap: () => navigateProvider(context),
        title: 'Provider',
        trailing: '',
      ),
      MobileSettingTile(
        onTap: () => navigateDefaultModel(context),
        title: 'Default Model',
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

  void navigateProvider(BuildContext context) {
    MobileProviderListRoute().push(context);
  }

  void navigateDefaultModel(BuildContext context) {}
}
