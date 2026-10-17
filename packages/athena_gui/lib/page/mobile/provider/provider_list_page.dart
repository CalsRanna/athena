import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileProviderListPage extends StatefulWidget {
  const MobileProviderListPage({super.key});

  @override
  State<MobileProviderListPage> createState() => _MobileProviderListPageState();
}

class _MobileProviderListPageState extends State<MobileProviderListPage> {
  final viewModel = GetIt.instance<ProviderViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();

  @override
  void initState() {
    super.initState();
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    try {
      await viewModel.initSignals();
      await modelViewModel.initSignals();
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load providers. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncButton = AthenaIconButton(
      icon: LucideIcons.refreshCw,
      onTap: () => syncFromModelsDev(context),
    );
    final addButton = AthenaIconButton(
      icon: LucideIcons.plus,
      onTap: () => navigateProviderNamePage(context),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        syncButton,
        const SizedBox(width: AthenaSpace.sm),
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
    const MobileProviderNameRoute().push<void>(context);
  }

  /// 一键同步 models.dev 的常用推理模型目录(force 忽略本地缓存)。
  Future<void> syncFromModelsDev(BuildContext context) async {
    if (viewModel.isSyncing.value) return;
    AthenaDialog.loading();
    final result = await viewModel.syncCatalog();
    if (!context.mounted) return;
    AthenaDialog.dismiss();
    if (result == null) {
      AthenaDialog.error('Sync failed: ${viewModel.error.value}');
      return;
    }
    AthenaDialog.success(
      'models.dev synced: +${result.createdProviders} providers, '
      '+${result.createdModels} models, ${result.updatedModels} updated, '
      '${result.removedModels} removed',
    );
  }

  Widget _buildBody(BuildContext context) {
    final providers = viewModel.providers.value;
    if (providers.isEmpty) {
      if (viewModel.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return MobileEmptyState(
        icon: AthenaIcons.connection,
        title: 'No providers',
        hint:
            'Sync the catalog from models.dev to get the preset providers, '
            'or add one by hand.',
        action: Wrap(
          spacing: AthenaSpace.sm,
          runSpacing: AthenaSpace.sm,
          alignment: WrapAlignment.center,
          children: [
            AthenaSecondaryButton.small(
              onTap: () => syncFromModelsDev(context),
              child: const Text('Sync from models.dev'),
            ),
            AthenaSecondaryButton.small(
              onTap: () => navigateProviderNamePage(context),
              child: const Text('Add provider'),
            ),
          ],
        ),
      );
    }
    final enabled = viewModel.enabledProviders.value;
    final disabled = viewModel.disabledProviders.value;
    final models = modelViewModel.models.value;
    final children = [
      if (enabled.isNotEmpty) _buildGroup(context, 'Enabled', enabled, models),
      if (disabled.isNotEmpty)
        _buildGroup(context, 'Disabled', disabled, models),
    ];
    return RefreshIndicator(
      onRefresh: viewModel.initSignals,
      child: ListView(
        padding: EdgeInsets.only(
          top: AthenaSpace.sm,
          bottom: AthenaSpace.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String title,
    List<ProviderEntity> providers,
    List<ModelEntity> models,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AthenaSpace.lg,
            AthenaSpace.sm,
            AthenaSpace.lg,
            AthenaSpace.sm,
          ),
          child: Text(
            '$title · ${providers.length}',
            style: AthenaTextStyle.caption.copyWith(color: colors.textWeak),
          ),
        ),
        for (final (index, provider) in providers.indexed) ...[
          _ProviderListTile(
            provider,
            modelCount: models
                .where((model) => model.providerId == provider.id)
                .length,
          ),
          if (index != providers.length - 1) _buildSeparator(context),
        ],
      ],
    );
  }

  Widget _buildSeparator(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final divider = Divider(color: colors.border, height: 1, thickness: 1);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSpace.lg,
        vertical: AthenaSpace.sm,
      ),
      child: divider,
    );
  }
}

class _ProviderListTile extends StatelessWidget {
  final ProviderEntity provider;
  final int modelCount;
  const _ProviderListTile(this.provider, {required this.modelCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleTextStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
    );
    final subtitleTextStyle = AthenaTextStyle.row.copyWith(
      color: colors.textSecondary,
    );
    final titleChildren = [
      Flexible(
        child: Text(
          provider.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleTextStyle,
        ),
      ),
      if (provider.enabled) const SizedBox(width: AthenaSpace.sm),
      if (provider.enabled)
        Icon(
          LucideIcons.toggleRight,
          size: AthenaIcon.regularSize,
          color: colors.iconSecondary,
        ),
    ];
    final actionButton = AthenaGhostIconButton(
      icon: AthenaIcons.more,
      box: AthenaIconButtonSize.touchTarget,
      iconSize: AthenaIcon.regularSize,
      onTap: () => openBottomSheet(context),
    );
    final rowChildren = [
      Expanded(child: Row(children: titleChildren)),
      actionButton,
    ];
    final countLabel = modelCount == 1 ? '1 model' : '$modelCount models';
    final keyLabel = provider.apiKey.trim().isEmpty
        ? 'No API key'
        : 'API key set';
    final columnChildren = [
      Row(children: rowChildren),
      const SizedBox(height: AthenaSpace.xs),
      Text(
        '$countLabel · $keyLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: subtitleTextStyle,
      ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    final padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AthenaSpace.lg),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateProviderForm(context),
      child: padding,
    );
  }

  Future<void> destroyProvider() async {
    AthenaDialog.dismiss();
    final confirmed = await AthenaDialog.confirm(
      'Delete ${provider.name} and its models?',
    );
    if (confirmed != true) return;
    final viewModel = GetIt.instance<ProviderViewModel>();
    await viewModel.deleteProvider(provider);
    final error = viewModel.error.value;
    if (error != null) AthenaDialog.error(error);
  }

  void navigateProviderForm(BuildContext context) {
    MobileProviderFormRoute(provider: provider).push<void>(context);
  }

  void openBottomSheet(BuildContext context) {
    final enableText = provider.enabled ? 'Disable' : 'Enable';
    var enableIcon = LucideIcons.toggleLeft;
    if (provider.enabled) enableIcon = LucideIcons.toggleRight;
    final enableTile = AthenaBottomSheetTile(
      leading: Icon(enableIcon),
      title: enableText,
      onTap: () => toggleEnable(),
    );
    final deleteTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () => destroyProvider(),
    );
    final children = [enableTile, if (!provider.isPreset) deleteTile];
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: AthenaSpace.lg),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void toggleEnable() {
    final viewModel = GetIt.instance<ProviderViewModel>();
    final updatedProvider = provider.copyWith(enabled: !provider.enabled);
    viewModel.updateProvider(updatedProvider);
    AthenaDialog.dismiss();
  }
}
