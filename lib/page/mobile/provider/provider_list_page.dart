import 'package:athena/provider/provider.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
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

class _ProviderListTile extends ConsumerWidget {
  final schema.Provider provider;
  const _ProviderListTile(this.provider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    var titleChildren = [
      Flexible(child: Text(provider.name, style: titleTextStyle)),
      if (provider.enabled) const SizedBox(width: 8),
      if (provider.enabled) ATag.small(text: 'On'),
    ];
    var icon = Icon(
      HugeIcons.strokeRoundedMoreHorizontal,
      color: Color(0xFFE0E0E0),
      size: 16,
    );
    var actionButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBottomSheet(context, ref),
      child: icon,
    );
    var rowChildren = [
      Expanded(child: Row(children: titleChildren)),
      actionButton,
    ];
    var columnChildren = [
      Row(children: rowChildren),
      Text(provider.url, style: subtitleTextStyle),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateProviderForm(context),
      child: padding,
    );
  }

  void destroyProvider(WidgetRef ref) {
    var viewModel = ProviderViewModel(ref);
    viewModel.deleteProvider(provider);
    ADialog.dismiss();
  }

  void navigateProviderForm(BuildContext context) {
    MobileProviderFormRoute(provider: provider).push(context);
  }

  void openBottomSheet(BuildContext context, WidgetRef ref) {
    var enableText = provider.enabled ? 'Disable' : 'Enable';
    var enableIcon = HugeIcons.strokeRoundedToggleOff;
    if (provider.enabled) enableIcon = HugeIcons.strokeRoundedToggleOn;
    var enableTile = ABottomSheetTile(
      leading: Icon(enableIcon),
      title: enableText,
      onTap: () => toggleEnable(ref),
    );
    var deleteTile = ABottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyProvider(ref),
    );
    var children = [enableTile, if (!provider.isPreset) deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    ADialog.show(SafeArea(child: padding));
  }

  void toggleEnable(WidgetRef ref) {
    var viewModel = ProviderViewModel(ref);
    viewModel.toggleEnabled(provider);
    ADialog.dismiss();
  }
}
