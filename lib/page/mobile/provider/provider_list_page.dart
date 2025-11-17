import 'package:athena/entity/ai_provider_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/ai_provider_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileProviderListPage extends StatelessWidget {
  const MobileProviderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    var button = AthenaIconButton(
      icon: HugeIcons.strokeRoundedAdd01,
      onTap: () => navigateProviderName(context),
    );
    return Watch((context) {
      var providerViewModel = GetIt.instance<AIProviderViewModel>();
      var providers = providerViewModel.providers.value;
      return AthenaScaffold(
        appBar: AthenaAppBar(action: button, title: const Text('Provider')),
        body: _buildBody(providers),
      );
    });
  }

  void navigateProviderName(BuildContext context) {
    MobileProviderNameRoute().push(context);
  }

  Widget _buildBody(List<AIProviderEntity> providers) {
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
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: divider,
    );
  }
}

class _ProviderListTile extends StatelessWidget {
  final AIProviderEntity provider;
  const _ProviderListTile(this.provider);

  @override
  Widget build(BuildContext context) {
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: ColorUtil.FFFFFFFF,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: ColorUtil.FFE0E0E0,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var titleChildren = [
      Flexible(child: Text(provider.name, style: titleTextStyle)),
      if (provider.enabled) const SizedBox(width: 8),
      if (provider.enabled) AthenaTag.small(text: 'On'),
    ];
    var icon = Icon(
      HugeIcons.strokeRoundedMoreHorizontal,
      color: ColorUtil.FFE0E0E0,
      size: 16,
    );
    var actionButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openBottomSheet(context),
      child: icon,
    );
    var rowChildren = [
      Expanded(child: Row(children: titleChildren)),
      actionButton,
    ];
    var columnChildren = [
      Row(children: rowChildren),
      Text(provider.baseUrl, style: subtitleTextStyle),
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

  void destroyProvider() {
    var viewModel = GetIt.instance<AIProviderViewModel>();
    viewModel.deleteProvider(provider);
    AthenaDialog.dismiss();
  }

  void navigateProviderForm(BuildContext context) {
    MobileProviderFormRoute(provider: provider).push(context);
  }

  void openBottomSheet(BuildContext context) {
    var enableText = provider.enabled ? 'Disable' : 'Enable';
    var enableIcon = HugeIcons.strokeRoundedToggleOff;
    if (provider.enabled) enableIcon = HugeIcons.strokeRoundedToggleOn;
    var enableTile = AthenaBottomSheetTile(
      leading: Icon(enableIcon),
      title: enableText,
      onTap: () => toggleEnable(),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyProvider(),
    );
    var children = [enableTile, if (!provider.isPreset) deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void toggleEnable() {
    var viewModel = GetIt.instance<AIProviderViewModel>();
    var updatedProvider = provider.copyWith(enabled: !provider.enabled);
    viewModel.updateProvider(updatedProvider);
    AthenaDialog.dismiss();
  }
}
