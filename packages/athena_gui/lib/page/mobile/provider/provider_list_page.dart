import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileProviderListPage extends StatefulWidget {
  const MobileProviderListPage({super.key});

  @override
  State<MobileProviderListPage> createState() => _MobileProviderListPageState();
}

class _MobileProviderListPageState extends State<MobileProviderListPage> {
  final viewModel = GetIt.instance<ProviderViewModel>();

  @override
  void initState() {
    super.initState();
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    try {
      await viewModel.initSignals();
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load providers. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var syncButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedRefresh,
      onTap: () => syncFromModelsDev(context),
    );
    var addButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedAdd01,
      onTap: () => navigateProviderNamePage(context),
    );
    var actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        syncButton,
        const SizedBox(width: 8),
        addButton,
      ],
    );
    return Watch((context) {
      return AthenaScaffold(
        appBar: AthenaAppBar(action: actions, title: const Text('Provider')),
        body: Watch((context) => _buildBody(context)),
      );
    });
  }

  void navigateProviderNamePage(BuildContext context) {
    MobileProviderNameRoute().push(context);
  }

  /// 一键同步 models.dev 的常用推理模型目录(force 忽略本地缓存)。
  Future<void> syncFromModelsDev(BuildContext context) async {
    AthenaDialog.loading();
    try {
      final service = GetIt.instance<ModelCatalogService>();
      final result = await service.syncIfNeeded(force: true);
      await viewModel.initSignals();
      await GetIt.instance<ModelViewModel>().initSignals();
      if (!context.mounted) return;
      AthenaDialog.dismiss();
      AthenaDialog.success(
        'models.dev synced: +${result.createdProviders} providers, '
        '+${result.createdModels} models, ${result.updatedModels} updated, '
        '${result.removedModels} removed',
      );
    } catch (e) {
      if (!context.mounted) return;
      AthenaDialog.dismiss();
      AthenaDialog.error('Sync failed: $e');
    }
  }

  Widget _buildBody(BuildContext context) {
    var providers = viewModel.providers.value;
    if (providers.isEmpty) return const SizedBox();
    return ListView.separated(
      itemCount: providers.length,
      itemBuilder: (_, index) => _ProviderListTile(providers[index]),
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => _buildSeparator(context),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var divider = Divider(
      color: colors.borderFaint.withValues(alpha: 0.2),
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
  final ProviderEntity provider;
  const _ProviderListTile(this.provider);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleTextStyle = TextStyle(
      fontSize: 16,
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    final subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: colors.iconSecondary,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var titleChildren = [
      Flexible(child: Text(provider.name, style: titleTextStyle)),
      if (provider.enabled) SizedBox(width: 8),
      if (provider.enabled)
        Icon(
          HugeIcons.strokeRoundedToggleOn,
          size: 16,
          color: colors.iconSecondary,
        ),
    ];
    var icon = Icon(
      HugeIcons.strokeRoundedMoreHorizontal,
      color: colors.iconSecondary,
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
    var viewModel = GetIt.instance<ProviderViewModel>();
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
    var viewModel = GetIt.instance<ProviderViewModel>();
    var updatedProvider = provider.copyWith(enabled: !provider.enabled);
    viewModel.updateProvider(updatedProvider);
    AthenaDialog.dismiss();
  }
}
