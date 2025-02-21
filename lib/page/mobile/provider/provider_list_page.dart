import 'package:athena/provider/provider.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:athena/schema/provider.dart' as schema;

@RoutePage()
class MobileProviderListPage extends ConsumerWidget {
  const MobileProviderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var providers = ref.watch(providersNotifierProvider).valueOrNull;
    Widget body = const SizedBox();
    if (providers != null) body = _buildBody(providers);
    return AScaffold(
      appBar: AAppBar(title: const Text('Provider')),
      body: body,
    );
  }

  Widget _buildBody(List<schema.Provider> providers) {
    if (providers.isEmpty) return const SizedBox();
    return ListView.builder(
      itemCount: providers.length,
      itemBuilder: (context, index) {
        var provider = providers[index];
        return MobileSettingTile(
          title: provider.name,
          subtitle: provider.url,
          onTap: () => navigateProvider(context, provider),
        );
      },
      padding: EdgeInsets.zero,
    );
  }

  void navigateProvider(BuildContext context, schema.Provider provider) {
    MobileProviderFormRoute(provider: provider).push(context);
  }
}
