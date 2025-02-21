import 'package:athena/provider/provider.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProviderListPage extends ConsumerWidget {
  const MobileProviderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var button = AIconButton(
      icon: HugeIcons.strokeRoundedAdd01,
      onTap: () => navigateProviderName(context),
    );
    var providers = ref.watch(providersNotifierProvider).valueOrNull;
    Widget body = const SizedBox();
    if (providers != null) body = _buildBody(providers);
    return AScaffold(
      appBar: AAppBar(action: button, title: const Text('Provider')),
      body: body,
    );
  }

  void navigateProvider(BuildContext context, schema.Provider provider) {
    MobileProviderFormRoute(provider: provider).push(context);
  }

  void navigateProviderName(BuildContext context) {
    MobileProviderNameRoute().push(context);
  }

  Widget _buildBody(List<schema.Provider> providers) {
    if (providers.isEmpty) return const SizedBox();
    return ListView.separated(
      itemCount: providers.length,
      itemBuilder: (_, index) => _ProviderListTile(providers[index]),
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => _buildSeparator(),
    );
  }

  Widget _buildSeparator() {
    var divider = Divider(
      color: Color(0xFFFFFFFF).withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: divider,
    );
  }
}

class _ProviderBottomSheet extends ConsumerWidget {
  final schema.Provider provider;
  const _ProviderBottomSheet(this.provider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var enableText = provider.enabled ? 'Disable' : 'Enable';
    var toggleButton = ASecondaryButton(
      onTap: () => toggleEnable(ref),
      child: Center(child: Text(enableText)),
    );
    var deleteButton = ASecondaryButton(
      onTap: () => destroyProvider(ref),
      child: Center(child: Text('Delete')),
    );
    var children = [
      toggleButton,
      if (!provider.isPreset) const SizedBox(height: 12),
      if (!provider.isPreset) deleteButton,
    ];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(child: column),
    );
  }

  void destroyProvider(WidgetRef ref) {
    var viewModel = ProviderViewModel(ref);
    viewModel.deleteProvider(provider);
    ADialog.dismiss();
  }

  void toggleEnable(WidgetRef ref) {
    var viewModel = ProviderViewModel(ref);
    viewModel.toggleEnabled(provider);
    ADialog.dismiss();
  }
}

class _ProviderListTile extends StatelessWidget {
  final schema.Provider provider;
  const _ProviderListTile(this.provider);

  @override
  Widget build(BuildContext context) {
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: Color(0xFFE0E0E0),
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var nameChildren = [
      Flexible(child: Text(provider.name, style: titleTextStyle)),
      if (provider.enabled) const SizedBox(width: 8),
      if (provider.enabled) ATag.small(text: 'On')
    ];
    var titleChildren = [
      Row(children: nameChildren),
      Text(provider.url, style: subtitleTextStyle)
    ];
    var titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: titleChildren,
    );
    var tileChildren = [
      Expanded(child: titleColumn),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openBottomSheet(context),
        child: Icon(HugeIcons.strokeRoundedMoreHorizontal),
      ),
    ];
    var tileRow = IconTheme(
      data: const IconThemeData(color: Color(0xFFE0E0E0), size: 16),
      child: Row(children: tileChildren),
    );
    return ListTile(title: tileRow, onTap: () => navigateProviderForm(context));
  }

  void navigateProviderForm(BuildContext context) {
    MobileProviderFormRoute(provider: provider).push(context);
  }

  void openBottomSheet(BuildContext context) {
    ADialog.show(_ProviderBottomSheet(provider));
  }
}
