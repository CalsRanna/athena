import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/api_format_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_name_form.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/component/desktop_list_selection.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_label.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/list_pane.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

enum _Status implements SettingsListOption {
  all('All statuses'),
  enabled('Enabled'),
  disabled('Disabled');

  const _Status(this.label);
  @override
  final String label;
}

enum _Sort implements SettingsListOption {
  name('Name'),
  models('Model count');

  const _Sort(this.label);
  @override
  final String label;
}

/// 桌面端 Providers：单列列表 → 点进一家的详情（标题带里出现 `← Providers`）。
///
/// 设置没有第二列导航，条目集合
/// 走的是**列表行 → 钻取**。列表行的状态点表示是否启用，说明写模型数与
/// 密钥状态；详情页放密钥、地址、模型清单，改了即存（失焦提交）。
///
/// 列表仍支持 ⌘ / ⇧ 多选与右键（批量删除自定义 provider）；普通点击钻取。
@RoutePage()
class DesktopSettingProviderPage extends StatefulWidget {
  const DesktopSettingProviderPage({super.key});

  @override
  State<DesktopSettingProviderPage> createState() =>
      _DesktopSettingProviderPageState();
}

class _DesktopSettingProviderPageState
    extends State<DesktopSettingProviderPage> {
  final modelViewModel = GetIt.instance<ModelViewModel>();
  final providerViewModel = GetIt.instance<ProviderViewModel>();

  /// 正在查看的 provider；null 表示停在列表。
  String? openId;
  bool adding = false;
  bool showDisabled = false;
  final searchController = TextEditingController();
  _Status status = _Status.all;
  _Sort sort = _Sort.name;
  final listController = ScrollController();
  final _selection = DesktopListSelection<String>();
  final nameController = TextEditingController();
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  void dispose() {
    listController.dispose();
    searchController.dispose();
    nameController.dispose();
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _initState() async {
    await providerViewModel.initSignals();
    await modelViewModel.initSignals();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final providers = providerViewModel.providers.value;
        final open = providers.where((p) => p.id == openId).firstOrNull;
        if (open == null) return _buildList(providers);
        return _buildDetail(open);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<ProviderEntity> providers) {
    final query = searchController.text.trim().toLowerCase();
    final modelsByProvider = <String, List<ModelEntity>>{};
    for (final model in modelViewModel.models.value) {
      (modelsByProvider[model.providerId] ??= []).add(model);
    }
    final matches = providers.where((p) {
      if (status == _Status.enabled && !p.enabled ||
          status == _Status.disabled && p.enabled) {
        return false;
      }
      return p.name.toLowerCase().contains(query) ||
          p.baseUrl.toLowerCase().contains(query) ||
          (modelsByProvider[p.id]?.any(
                (m) =>
                    m.name.toLowerCase().contains(query) ||
                    m.modelId.toLowerCase().contains(query),
              ) ??
              false);
    }).toList();
    matches.sort((a, b) {
      if (sort == _Sort.models) {
        final byCount = (modelsByProvider[b.id]?.length ?? 0).compareTo(
          modelsByProvider[a.id]?.length ?? 0,
        );
        if (byCount != 0) return byCount;
      }
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return (a.id ?? '').compareTo(b.id ?? '');
    });
    final enabled = matches.where((p) => p.enabled).toList();
    final disabled = matches.where((p) => !p.enabled).toList();
    final filtering = query.isNotEmpty || status != _Status.all;
    final expandDisabled = filtering || showDisabled;
    final selectableIds = [
      for (final p in [...enabled, if (expandDisabled) ...disabled])
        if (!p.isPreset && p.id != null) p.id!,
    ];
    Widget row(ProviderEntity provider) => _buildProviderRow(
      provider,
      modelsByProvider[provider.id]?.length ?? 0,
      selectableIds,
    );
    return AthenaSettingsListPane(
      title: 'Providers',
      controller: listController,
      searchController: searchController,
      onSearchChanged: (_) => setState(_selection.clear),
      filterBy: 'status',
      filter: status,
      filters: _Status.values,
      onFilterChanged: (option) => setState(() {
        status = option;
        _selection.clear();
      }),
      sort: sort,
      sorts: _Sort.values,
      onSortChanged: (option) => setState(() {
        sort = option;
        _selection.clear();
      }),
      onAdd: adding ? null : createProvider,
      menus: [
        Tooltip(
          message: _syncDescription(),
          child: AthenaGhostIconButton(
            icon: LucideIcons.cloudCheck,
            onTap: syncFromModelsDev,
          ),
        ),
      ],
      children: [
        if (adding)
          AthenaSettingsInset(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: DesktopProviderNameForm(
              onCancel: () => setState(() => adding = false),
              onStored: _openProvider,
            ),
          ),
        if (providers.isEmpty)
          AthenaSettingsEmptyState(
            icon: AthenaIcons.connection,
            title: 'No providers',
            hint:
                'Sync the catalog from models.dev to get the preset providers, '
                'or add one by hand.',
            action: AthenaSecondaryButton.small(
              onTap: syncFromModelsDev,
              child: const Text('Sync from models.dev'),
            ),
          )
        else if (matches.isEmpty)
          const AthenaSettingsEmptyState(
            icon: LucideIcons.search,
            title: 'No matching providers',
            hint: 'Try another search or change the status filter.',
          )
        else ...[
          if (enabled.isNotEmpty || !filtering)
            AthenaSettingsSection(
              first: true,
              title: 'Enabled · ${enabled.length}',
              children: [for (final p in enabled) row(p)],
            ),
          if (disabled.isNotEmpty || !filtering) ...[
            if (enabled.isNotEmpty || !filtering)
              const SizedBox(height: AthenaSpace.lg),
            if (filtering)
              AthenaSettingsSection(
                first: true,
                title: 'Disabled · ${disabled.length}',
                children: [for (final p in disabled) row(p)],
              )
            else ...[
              _disabledHeader(disabled.length),
              if (showDisabled)
                AthenaSettingsGroup(
                  children: [for (final p in disabled) row(p)],
                ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _disabledHeader(int count) => AthenaSettingsInset(
    child: AthenaHover(
      onTap: () => setState(() {
        showDisabled = !showDisabled;
        _selection.clear();
      }),
      builder: (context, hover) => Row(
        children: [
          Icon(
            showDisabled ? LucideIcons.chevronDown : LucideIcons.chevronRight,
            size: AthenaIcon.inlineSize,
            color: context.athenaColors.iconSecondary,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Disabled · $count',
              style: AthenaTextStyle.caption.copyWith(
                color: hover
                    ? context.athenaColors.textPrimary
                    : context.athenaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildProviderRow(
    ProviderEntity provider,
    int count,
    List<String> selectableIds,
  ) {
    return AthenaSettingsListRow(
      label: provider.name,
      labelMaxLines: 1,
      badge: provider.isPreset ? null : 'Custom',
      description: provider.apiKey.trim().isEmpty
          ? 'No API key'
          : 'API key set',
      metadata: count == 1 ? '1 model' : '$count models',
      dimmed: !provider.enabled,
      selected: _selection.selectedIds.contains(provider.id),
      onTap: () => _handleProviderTap(provider, selectableIds),
      onSecondaryTap: (details) => _openProviderContextMenu(details, provider),
    );
  }

  String _syncDescription() {
    const what =
        'Refreshes the preset providers and their models. Models you added '
        'yourself are kept.';
    final syncedAt = providerViewModel.lastSyncedAt.value;
    if (syncedAt == null) return '$what Never synced.';
    return '$what Last synced ${_relative(syncedAt)}.';
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    String pad(int n) => n.toString().padLeft(2, '0');
    return 'on ${time.year}-${pad(time.month)}-${pad(time.day)}';
  }

  void _handleProviderTap(ProviderEntity provider, List<String> selectableIds) {
    final activate = _selection.handleTap(provider.id, ids: selectableIds);
    if (activate) {
      _openProvider(provider);
    } else {
      setState(() {});
    }
  }

  void _openProvider(ProviderEntity provider) {
    _selection.clear();
    nameController.text = provider.name;
    keyController.text = provider.apiKey;
    urlController.text = provider.baseUrl;
    setState(() {
      adding = false;
      openId = provider.id;
    });
  }

  void _closeProvider() {
    setState(() => openId = null);
  }

  void _openProviderContextMenu(TapUpDetails details, ProviderEntity provider) {
    final selected = providerViewModel.providers.value
        .where((item) => _selection.selectedIds.contains(item.id))
        .toList();
    final multiSelect = selected.length > 1 && selected.contains(provider);
    final targets = multiSelect ? selected : [provider];
    final deletable = targets.where((item) => !item.isPreset).toList();
    final menu = DesktopContextMenu(
      offset: details.globalPosition,
      width: 160,
      children: [
        if (!multiSelect)
          DesktopContextMenuTile(
            text: 'Open',
            onTap: () => _openProvider(provider),
          ),
        if (!multiSelect)
          DesktopContextMenuTile(
            text: provider.enabled ? 'Disable' : 'Enable',
            onTap: () => providerViewModel.toggleEnabled(provider),
          ),
        if (!multiSelect && !provider.isPreset)
          DesktopContextMenuTile(
            text: 'Rename',
            onTap: () => openProviderFormDialog(provider),
          ),
        if (deletable.isNotEmpty) const DesktopContextMenuSeparator(),
        if (deletable.isNotEmpty)
          DesktopContextMenuTile(
            text: deletable.length > 1
                ? 'Delete ${deletable.length} providers'
                : 'Delete',
            danger: true,
            onTap: () => destroyProviders(deletable),
          ),
      ],
    );
    DesktopContextMenuManager.instance.show(context, menu);
  }

  // ---------------------------------------------------------------------------
  // 详情
  // ---------------------------------------------------------------------------

  Widget _buildDetail(ProviderEntity provider) {
    final colors = context.athenaColors;
    final models = modelViewModel.models.value
        .where((m) => m.providerId == provider.id)
        .toList();
    final modelCount = models.length == 1
        ? '1 model'
        : '${models.length} models';
    return AthenaSettingsPane(
      title: provider.name,
      header: AthenaSettingsBackLink(label: 'Providers', onTap: _closeProvider),
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Connection',
          description: provider.isPreset
              ? 'Preset provider. Its models are kept in sync with models.dev.'
              : 'Custom provider. Any OpenAI-compatible endpoint works.',
          trailing: AthenaSwitch(
            value: provider.enabled,
            onChanged: (_) => providerViewModel.toggleEnabled(provider),
          ),
          children: [
            if (!provider.isPreset)
              AthenaSettingsRow(
                label: 'Name',
                control: SizedBox(
                  width: AthenaSettingsControlWidth.wide,
                  child: AthenaSettingsTextField(
                    controller: nameController,
                    onBlur: () => _commitName(provider),
                    onSubmitted: (_) => _commitName(provider),
                  ),
                ),
              ),
            AthenaSettingsRow(
              label: 'API key',
              description: provider.apiKey.trim().isEmpty
                  ? 'Required before any of its models can be used.'
                  : 'Stored locally in providers/.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: keyController,
                  placeholder: 'sk-',
                  obscure: true,
                  onBlur: () => _commitKey(provider),
                  onSubmitted: (_) => _commitKey(provider),
                ),
              ),
            ),
            AthenaSettingsRow(
              label: 'API URL',
              description: 'Base URL of the OpenAI-compatible API.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: urlController,
                  placeholder: 'https://api.example.com/v1',
                  onBlur: () => _commitUrl(provider),
                  onSubmitted: (_) => _commitUrl(provider),
                ),
              ),
            ),
            AthenaSettingsRow(
              label: 'API format',
              description: _apiFormatDescription(provider),
              control: DesktopSettingApiFormatSelector(
                provider: provider,
                onSelected: ({required bool auto, ApiFormat? format}) =>
                    _commitApiFormat(provider, auto: auto, format: format),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Models',
          description: models.isEmpty
              ? null
              : '$modelCount. Test a model to check the key and URL.',
          trailing: AthenaSecondaryButton.small(
            onTap: () => createModel(provider),
            child: const Text('Add model'),
          ),
          children: _buildModelRows(provider, models, colors),
        ),
        if (!provider.isPreset)
          AthenaSettingsSection(
            title: 'Danger zone',
            children: [
              AthenaSettingsRow(
                label: 'Delete provider',
                description:
                    'Removes ${provider.name} and its $modelCount. Sessions that '
                    'used them fall back to the default model.',
                control: AthenaSecondaryButton.small(
                  onTap: () => destroyProviders([provider]),
                  child: Text(
                    'Delete',
                    style: AthenaTextStyle.label.copyWith(
                      color: colors.dangerText,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Widget> _buildModelRows(
    ProviderEntity provider,
    List<ModelEntity> models,
    AthenaColors colors,
  ) {
    if (models.isEmpty) {
      return [
        AthenaSettingsEmptyState(
          icon: LucideIcons.cpu,
          title: 'No models',
          hint: provider.isPreset
              ? 'Sync from models.dev on the Providers page, or add one by hand.'
              : 'Add the models this endpoint serves.',
          action: AthenaSecondaryButton.small(
            onTap: () => createModel(provider),
            child: const Text('Add model'),
          ),
        ),
      ];
    }
    return [
      for (final model in models)
        AthenaSettingsRow(
          label: model.name,
          badge: model.isPreset ? null : 'Custom',
          description: ModelLabel.modelSubtitle(model),
          descriptionMaxLines: 1,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCapabilities(model, colors),
              Text(
                model.modelId,
                style: AthenaTextStyle.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              AthenaSettingsMenuButton(
                items: [
                  DesktopContextMenuTile(
                    text: 'Test connection',
                    onTap: () => checkConnection(model),
                  ),
                  DesktopContextMenuTile(
                    text: 'Edit',
                    onTap: () => editModel(provider, model),
                  ),
                  const DesktopContextMenuSeparator(),
                  DesktopContextMenuTile(
                    text: 'Delete',
                    danger: true,
                    onTap: () => destroyModel(model),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildCapabilities(ModelEntity model, AthenaColors colors) {
    final icons = <Widget>[
      if (model.reasoning)
        Tooltip(
          message: 'Reasoning',
          child: Icon(
            LucideIcons.brainCircuit,
            size: AthenaIcon.inlineSize,
            color: colors.iconSecondary,
          ),
        ),
      if (model.vision)
        Tooltip(
          message: 'Vision',
          child: Icon(
            LucideIcons.eye,
            size: AthenaIcon.inlineSize,
            color: colors.iconSecondary,
          ),
        ),
    ];
    if (icons.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < icons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            icons[i],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> _commitName(ProviderEntity provider) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      nameController.text = provider.name;
      return;
    }
    if (name == provider.name) return;
    await providerViewModel.updateProvider(provider.copyWith(name: name));
  }

  Future<void> _commitKey(ProviderEntity provider) async {
    final key = keyController.text.trim();
    if (key == provider.apiKey) return;
    await providerViewModel.updateProvider(provider.copyWith(apiKey: key));
  }

  Future<void> _commitUrl(ProviderEntity provider) async {
    final url = urlController.text.trim();
    if (url == provider.baseUrl) return;
    await providerViewModel.updateProvider(provider.copyWith(baseUrl: url));
  }

  /// 手动选择会把 `apiFormatAuto` 置为 false（`copyWith(apiFormat:)` 的语义，
  /// 见 `ProviderEntity`）；选回 Auto 只把开关打回去，格式值保留当前同步结果，
  /// 等下次目录同步覆盖。
  Future<void> _commitApiFormat(
    ProviderEntity provider, {
    required bool auto,
    ApiFormat? format,
  }) async {
    if (auto) {
      if (provider.apiFormatAuto) return;
      await providerViewModel.updateProvider(
        provider.copyWith(apiFormatAuto: true),
      );
      return;
    }
    if (format == null) return;
    if (!provider.apiFormatAuto && provider.apiFormat == format) return;
    await providerViewModel.updateProvider(
      provider.copyWith(apiFormat: format),
    );
  }

  String _apiFormatDescription(ProviderEntity provider) {
    if (provider.apiFormatAuto) {
      return 'Follows the format inferred from models.dev during sync.';
    }
    return 'Chosen manually; sync will not overwrite it.';
  }

  Future<void> checkConnection(ModelEntity model) async {
    AthenaDialog.loading();
    try {
      final result = await modelViewModel.checkConnection(model);
      AthenaDialog.dismiss();
      if (!result.isSuccess) {
        AthenaDialog.error(result.detail ?? result.message);
        return;
      }
      AthenaDialog.success(result.message);
    } catch (e) {
      AthenaDialog.dismiss();
      AthenaDialog.error('Connection error: $e');
    }
  }

  void createModel(ProviderEntity provider) {
    AthenaDialog.show(DesktopModelFormDialog(provider: provider));
  }

  void editModel(ProviderEntity provider, ModelEntity model) {
    AthenaDialog.show(DesktopModelFormDialog(provider: provider, model: model));
  }

  Future<void> destroyModel(ModelEntity model) async {
    final result = await AthenaDialog.confirm('Delete ${model.name}?');
    if (result == true) {
      await modelViewModel.deleteModel(model);
    }
  }

  void createProvider() {
    if (listController.hasClients) listController.jumpTo(0);
    setState(() => adding = true);
  }

  void openProviderFormDialog(ProviderEntity provider) {
    AthenaDialog.show(
      AthenaDesktopDialog(
        title: 'Rename provider',
        onClose: AthenaDialog.dismiss,
        child: DesktopProviderNameForm(
          provider: provider,
          onCancel: AthenaDialog.dismiss,
          onStored: (_) => AthenaDialog.dismiss(),
        ),
      ),
    );
  }

  Future<void> destroyProviders(List<ProviderEntity> targets) async {
    final deletable = targets
        .where((item) => !item.isPreset && item.id != null)
        .toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Delete ${deletable.single.name} and its models?'
          : 'Delete ${deletable.length} providers and their models?',
    );
    if (confirmed != true) return;
    for (final provider in deletable) {
      await providerViewModel.deleteProvider(provider);
      final remaining = providerViewModel.providers.value;
      if (remaining.any((item) => item.id == provider.id)) {
        if (mounted) {
          AthenaDialog.error(
            providerViewModel.error.value ?? 'Failed to delete provider',
          );
        }
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selection.clear();
      if (deletable.any((item) => item.id == openId)) openId = null;
    });
  }

  /// 一键同步 models.dev 的常用推理模型目录(force 忽略本地缓存)。
  Future<void> syncFromModelsDev() async {
    if (providerViewModel.isSyncing.value) return;
    AthenaDialog.loading();
    final result = await providerViewModel.syncCatalog();
    if (!mounted) return;
    AthenaDialog.dismiss();
    if (result == null) {
      AthenaDialog.error('Sync failed: ${providerViewModel.error.value}');
      return;
    }
    AthenaDialog.success(
      'Synced: +${result.createdProviders} providers, '
      '+${result.createdModels} models, ${result.updatedModels} updated, '
      '${result.removedModels} removed',
    );
  }
}
