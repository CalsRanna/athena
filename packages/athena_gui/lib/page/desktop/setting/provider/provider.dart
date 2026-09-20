import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/util/context_window_util.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/settings_panel.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopSettingProviderPage extends StatefulWidget {
  const DesktopSettingProviderPage({super.key});

  @override
  State<DesktopSettingProviderPage> createState() =>
      _DesktopSettingProviderPageState();
}

class _DesktopSettingProviderPageState
    extends State<DesktopSettingProviderPage> {
  late final ModelViewModel modelViewModel;
  late final ProviderViewModel providerViewModel;

  int index = 0;
  final _selection = DesktopListSelection<int>();
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    modelViewModel = GetIt.instance<ModelViewModel>();
    providerViewModel = GetIt.instance<ProviderViewModel>();
    _initState();
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildListColumn(),
      Expanded(child: _buildDetailPane()),
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Future<void> changeProvider(int index) async {
    setState(() {
      this.index = index;
    });
    var providers = providerViewModel.providers.value;
    if (providers.isEmpty) return;
    keyController.text = providers[index].apiKey;
    urlController.text = providers[index].baseUrl;
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

  void createProvider() {
    AthenaDialog.show(DesktopProviderFormDialog());
  }

  Future<void> destroyModel(ModelEntity model) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this model?',
    );
    if (result == true) {
      await modelViewModel.deleteModel(model);
    }
  }

  void _handleProviderTap(int tappedIndex) {
    final providers = providerViewModel.providers.value;
    final provider = providers[tappedIndex];
    final activate = _selection.handleTap(
      provider.id,
      ids: providers
          .where((item) => !item.isPreset && item.id != null)
          .map((item) => item.id!)
          .toList(),
      activeId: index < providers.length ? providers[index].id : null,
    );
    if (activate) {
      changeProvider(tappedIndex);
    } else {
      setState(() {});
    }
  }

  Future<void> destroyProviders(List<ProviderEntity> targets) async {
    final deletable = targets
        .where((item) => !item.isPreset && item.id != null)
        .toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Do you want to delete this provider?'
          : 'Do you want to delete ${deletable.length} providers?',
    );
    if (confirmed == true) {
      for (final provider in deletable) {
        final before = providerViewModel.providers.value;
        final deletedIndex = before.indexWhere(
          (item) => item.id == provider.id,
        );
        final activeId = index < before.length ? before[index].id : null;
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
        if (!mounted) continue;
        if (remaining.isEmpty) {
          setState(() => index = 0);
          continue;
        }
        var nextIndex = remaining.indexWhere((item) => item.id == activeId);
        if (nextIndex < 0) {
          nextIndex = (deletedIndex - 1).clamp(0, remaining.length - 1);
        }
        await changeProvider(nextIndex);
      }
    }
    if (mounted) setState(_selection.clear);
  }

  Future<void> editModel(ModelEntity model) async {
    var provider = providerViewModel.providers.value
        .where((p) => p.id == model.providerId)
        .firstOrNull;
    if (provider == null) return;
    AthenaDialog.show(DesktopModelFormDialog(provider: provider, model: model));
  }

  Future<void> openModelContextMenu(
    TapUpDetails details,
    ModelEntity model,
  ) async {
    if (model.isPreset) return;
    var contextMenu = DesktopModelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onConnected: () => checkConnection(model),
      onDestroyed: () => destroyModel(model),
      onEdited: () => editModel(model),
    );
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void openProviderContextMenu(TapUpDetails details, ProviderEntity provider) {
    if (provider.isPreset) return;
    final selected = providerViewModel.providers.value
        .where((item) => _selection.selectedIds.contains(item.id))
        .toList();
    final multiSelect = selected.length > 1;
    var contextMenu = DesktopProviderContextMenu(
      multiSelect: multiSelect,
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyProviders(multiSelect ? selected : [provider]),
      onEdited: () => openProviderFormDialog(provider),
    );
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void openProviderFormDialog(ProviderEntity provider) async {
    AthenaDialog.show(DesktopProviderFormDialog(provider: provider));
  }

  Future<void> toggleProvider(bool value) async {
    var providers = providerViewModel.providers.value;
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(enabled: value);
    return providerViewModel.updateProvider(copiedProvider);
  }

  Future<void> updateKey() async {
    var providers = providerViewModel.providers.value;
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(apiKey: keyController.text);
    await providerViewModel.updateProvider(copiedProvider);
  }

  Future<void> updateUrl() async {
    var providers = providerViewModel.providers.value;
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(baseUrl: urlController.text);
    await providerViewModel.updateProvider(copiedProvider);
  }

  /// 一键同步 models.dev 的常用推理模型目录(force 忽略本地缓存)。
  Future<void> syncFromModelsDev() async {
    AthenaDialog.loading();
    try {
      final service = GetIt.instance<ModelCatalogService>();
      final result = await service.syncIfNeeded(force: true);
      await providerViewModel.initSignals();
      await modelViewModel.initSignals();
      if (!mounted) return;
      AthenaDialog.dismiss();
      AthenaDialog.success(
        'models.dev synced: +${result.createdProviders} providers, '
        '+${result.createdModels} models, ${result.updatedModels} updated, '
        '${result.removedModels} removed',
      );
    } catch (e) {
      if (!mounted) return;
      AthenaDialog.dismiss();
      AthenaDialog.error('Sync failed: $e');
    }
  }

  Widget _buildListColumn() {
    return Watch((context) {
      var providers = providerViewModel.providers.value;
      var rows = <Widget>[];
      for (var i = 0; i < providers.length; i++) {
        rows.add(_buildProviderRow(providers, i));
      }
      var footer = AthenaSettingsListItem(
        label: 'Sync models.dev',
        onTap: syncFromModelsDev,
      );
      return AthenaSettingsListColumn(
        title: 'Providers',
        onAdd: createProvider,
        footer: footer,
        children: rows,
      );
    });
  }

  Widget _buildProviderRow(List<ProviderEntity> providers, int index) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var provider = providers[index];
    final selected =
        this.index == index || _selection.selectedIds.contains(provider.id);
    var trailingColor = selected ? colors.textPrimary : colors.iconSecondary;
    var trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.enabled)
          Icon(HugeIcons.strokeRoundedToggleOn, size: 12, color: trailingColor),
        if (provider.isPreset) const SizedBox(width: 6),
        if (provider.isPreset)
          Icon(
            HugeIcons.strokeRoundedCircleLock01,
            size: 12,
            color: trailingColor,
          ),
      ],
    );
    return AthenaSettingsListItem(
      label: provider.name,
      selected: selected,
      trailing: trailing,
      onSecondaryTap: (details) => openProviderContextMenu(details, provider),
      onTap: () => _handleProviderTap(index),
    );
  }

  Widget _buildDetailPane() {
    return Watch((context) {
      var providers = providerViewModel.providers.value;
      if (providers.isEmpty || index >= providers.length) {
        return const AthenaSettingsPane(children: []);
      }
      var provider = providers[index];
      var models = modelViewModel.models.value
          .where((m) => m.providerId == provider.id)
          .toList();
      return AthenaSettingsPane(
        children: [
          AthenaSettingsSection(
            first: true,
            title: provider.name,
            trailing: AthenaSwitch(
              value: provider.enabled,
              onChanged: toggleProvider,
            ),
            children: [
              AthenaSettingsRow(
                label: 'API Key',
                control: _buildInput(keyController, updateKey),
              ),
              AthenaSettingsRow(
                label: 'API URL',
                control: _buildInput(urlController, updateUrl),
              ),
            ],
          ),
          AthenaSettingsSection(
            title: 'Models',
            trailing: AthenaSettingsIconButton(
              icon: HugeIcons.strokeRoundedAdd01,
              iconSize: 14,
              onTap: () => createModel(provider),
            ),
            children: _buildModelRows(models),
          ),
        ],
      );
    });
  }

  Widget _buildInput(TextEditingController controller, void Function() onBlur) {
    return SizedBox(
      width: AthenaSettings.controlColumnWidth,
      child: AthenaInput(controller: controller, onBlur: onBlur),
    );
  }

  List<Widget> _buildModelRows(List<ModelEntity> models) {
    if (models.isEmpty) {
      return [const AthenaSettingsEmptyState(text: 'No models')];
    }
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return [
      for (final model in models)
        AthenaSettingsRow(
          label: model.name,
          description: _modelSubtitle(model),
          onSecondaryTap: (details) => openModelContextMenu(details, model),
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (model.isPreset) ...[
                Icon(
                  HugeIcons.strokeRoundedCircleLock01,
                  size: 14,
                  color: colors.iconSecondary,
                ),
                const SizedBox(width: 8),
              ],
              AthenaTag.small(text: model.modelId),
            ],
          ),
        ),
    ];
  }

  /// 模型行的说明：发布日期 · 上下文窗口 · 价格；没有可显示项时返回 null。
  String? _modelSubtitle(ModelEntity model) {
    var parts = <String>[
      if (model.releasedAt.isNotEmpty) model.releasedAt,
      if (model.contextWindow > 0) formatContextWindow(model.contextWindow),
      if (model.inputPrice.isNotEmpty) model.inputPrice,
      if (model.outputPrice.isNotEmpty) model.outputPrice,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Future<void> _initState() async {
    await providerViewModel.initSignals();
    await modelViewModel.initSignals();
    var providers = providerViewModel.providers.value;
    if (providers.isEmpty) return;
    keyController.text = providers[index].apiKey;
    urlController.text = providers[index].baseUrl;
  }
}
