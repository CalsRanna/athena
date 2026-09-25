import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/api_format_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/util/model_label_util.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Providers：单列列表 → 点进一家的详情（标题带里出现 `← Providers`）。
///
/// 旧版是「列表列 + 详情列」三栏；Claude 的设置没有第二列导航，条目集合
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
  final catalogService = GetIt.instance<ModelCatalogService>();

  /// 正在查看的 provider；null 表示停在列表。
  int? openId;
  final _selection = DesktopListSelection<int>();
  final nameController = TextEditingController();
  final keyController = TextEditingController();
  final urlController = TextEditingController();
  DateTime? lastSyncedAt;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _initState() async {
    await providerViewModel.initSignals();
    await modelViewModel.initSignals();
    final syncedAt = await catalogService.lastSyncedAt();
    if (!mounted) return;
    setState(() => lastSyncedAt = syncedAt);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final providers = providerViewModel.providers.value;
      final open = providers.where((p) => p.id == openId).firstOrNull;
      if (open == null) return _buildList(providers);
      return _buildDetail(open);
    });
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<ProviderEntity> providers) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final models = modelViewModel.models.value;
    var rows = <Widget>[
      for (final provider in providers)
        _buildProviderRow(provider, models, colors),
    ];
    if (rows.isEmpty) {
      rows = [
        AthenaSettingsEmptyState(
          icon: LucideIcons.plug,
          title: 'No providers',
          hint:
              'Sync the catalog from models.dev to get the preset providers, '
              'or add one by hand.',
          action: AthenaSecondaryButton.small(
            onTap: syncFromModelsDev,
            child: const Text('Sync from models.dev'),
          ),
        ),
      ];
    }
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Providers',
          description:
              'Where models come from. Enable a provider and add its API key '
              'to use its models.',
          trailing: AthenaSecondaryButton.small(
            onTap: createProvider,
            child: const Text('Add provider'),
          ),
          children: rows,
        ),
        AthenaSettingsSection(
          title: 'Model catalog',
          children: [
            AthenaSettingsRow(
              label: 'Sync from models.dev',
              description: _syncDescription(),
              control: AthenaSecondaryButton.small(
                onTap: syncFromModelsDev,
                child: const Text('Sync now'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderRow(
    ProviderEntity provider,
    List<ModelEntity> models,
    AthenaColors colors,
  ) {
    final count = models.where((m) => m.providerId == provider.id).length;
    final parts = <String>[
      count == 1 ? '1 model' : '$count models',
      provider.apiKey.trim().isEmpty ? 'No API key' : 'API key set',
      if (!provider.enabled) 'Disabled',
    ];
    final dot = AthenaSettingsDot(
      color: provider.enabled ? colors.statusSuccess : colors.switchTrackOff,
    );
    return AthenaSettingsRow(
      label: provider.name,
      badge: provider.isPreset ? null : 'Custom',
      description: parts.join(' · '),
      leading: dot,
      chevron: true,
      selected: _selection.selectedIds.contains(provider.id),
      onTap: () => _handleProviderTap(provider),
      onSecondaryTap: (details) => _openProviderContextMenu(details, provider),
    );
  }

  String _syncDescription() {
    const what =
        'Refreshes the preset providers and their models. Models you added '
        'yourself are kept.';
    final syncedAt = lastSyncedAt;
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

  void _handleProviderTap(ProviderEntity provider) {
    final providers = providerViewModel.providers.value;
    final activate = _selection.handleTap(
      provider.id,
      ids: providers
          .where((item) => !item.isPreset && item.id != null)
          .map((item) => item.id!)
          .toList(),
    );
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
    setState(() => openId = provider.id);
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
    var menu = DesktopContextMenu(
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
            text: 'Rename…',
            onTap: () => openProviderFormDialog(provider),
          ),
        if (deletable.isNotEmpty) const DesktopContextMenuSeparator(),
        if (deletable.isNotEmpty)
          DesktopContextMenuTile(
            text: deletable.length > 1
                ? 'Delete ${deletable.length} providers…'
                : 'Delete…',
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final models = modelViewModel.models.value
        .where((m) => m.providerId == provider.id)
        .toList();
    final modelCount = models.length == 1 ? '1 model' : '${models.length} models';
    return AthenaSettingsPane(
      header: AthenaSettingsBackLink(
        label: 'Providers',
        onTap: _closeProvider,
      ),
      children: [
        AthenaSettingsSection(
          first: true,
          title: provider.name,
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
                  : 'Stored locally in setting.yaml.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: keyController,
                  placeholder: 'sk-…',
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
                  mono: true,
                  onBlur: () => _commitUrl(provider),
                  onSubmitted: (_) => _commitUrl(provider),
                ),
              ),
            ),
            AthenaSettingsRow(
              label: 'API format',
              description: _apiFormatDescription(provider),
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: DesktopSettingApiFormatSelect(
                  provider: provider,
                  onSelected: ({required bool auto, ApiFormat? format}) =>
                      _commitApiFormat(provider, auto: auto, format: format),
                ),
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
                    'Removes ${provider.name} and its $modelCount. Chats that '
                    'used them fall back to the default model.',
                control: AthenaSecondaryButton.small(
                  onTap: () => destroyProviders([provider]),
                  child: Text(
                    'Delete…',
                    style: TextStyle(color: colors.dangerText),
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
          description: modelSubtitle(model),
          descriptionMaxLines: 1,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCapabilities(model, colors),
              Text(
                model.modelId,
                style: athenaMono(color: colors.textSecondary),
              ),
              const SizedBox(width: 8),
              AthenaSettingsMenuButton(
                items: [
                  DesktopContextMenuTile(
                    text: 'Test connection',
                    onTap: () => checkConnection(model),
                  ),
                  DesktopContextMenuTile(
                    text: 'Edit…',
                    onTap: () => editModel(provider, model),
                  ),
                  const DesktopContextMenuSeparator(),
                  DesktopContextMenuTile(
                    text: 'Delete…',
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
    var icons = <Widget>[
      if (model.reasoning)
        Tooltip(
          message: 'Reasoning',
          child: Icon(
            LucideIcons.brainCircuit,
            size: 14,
            color: colors.iconSecondary,
          ),
        ),
      if (model.vision)
        Tooltip(
          message: 'Vision',
          child: Icon(
            LucideIcons.eye,
            size: 14,
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
    await providerViewModel.updateProvider(provider.copyWith(apiFormat: format));
  }

  String _apiFormatDescription(ProviderEntity provider) {
    if (provider.apiFormatAuto) {
      return 'Follows the format inferred from models.dev during sync.';
    }
    if (provider.apiFormat == ApiFormat.messages) {
      return 'Chosen manually. Messages is not wired up yet — requests fail '
          'until it ships.';
    }
    return 'Chosen manually; sync will not overwrite it.';
  }

  Future<void> checkConnection(ModelEntity model) async {
    AthenaDialog.loading();
    try {
      var result = await modelViewModel.checkConnection(model);
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
    var result = await AthenaDialog.confirm('Delete ${model.name}?');
    if (result == true) {
      await modelViewModel.deleteModel(model);
    }
  }

  void createProvider() {
    AthenaDialog.show(
      DesktopProviderFormDialog(
        onStored: (provider) {
          if (mounted) _openProvider(provider);
        },
      ),
    );
  }

  void openProviderFormDialog(ProviderEntity provider) {
    AthenaDialog.show(DesktopProviderFormDialog(provider: provider));
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
    AthenaDialog.loading();
    try {
      final result = await catalogService.syncIfNeeded(force: true);
      await providerViewModel.initSignals();
      await modelViewModel.initSignals();
      final syncedAt = await catalogService.lastSyncedAt();
      if (!mounted) return;
      AthenaDialog.dismiss();
      setState(() => lastSyncedAt = syncedAt);
      AthenaDialog.success(
        'Synced: +${result.createdProviders} providers, '
        '+${result.createdModels} models, ${result.updatedModels} updated, '
        '${result.removedModels} removed',
      );
    } catch (e) {
      if (!mounted) return;
      AthenaDialog.dismiss();
      AthenaDialog.error('Sync failed: $e');
    }
  }
}
