import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/util/context_window_util.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String model = '';
  int index = 0;
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
      _buildProviderListView(),
      Expanded(child: _buildProviderView()),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
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

  Future<void> destroyModel(ModelEntity model) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this model?',
    );
    if (result == true) {
      await modelViewModel.deleteModel(model);
    }
  }

  Future<void> destroyProvider(ProviderEntity provider) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this provider?',
    );
    if (result == true) {
      await providerViewModel.deleteProvider(provider);
      setState(() {
        index = 0;
      });
    }
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
    var contextMenu = DesktopProviderContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyProvider(provider),
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

  List<Widget> _buildModelListView(List<ModelEntity>? models) {
    if (models == null) return [const SizedBox()];
    if (models.isEmpty) return [const SizedBox()];
    List<Widget> children = [];
    for (var model in models) {
      var child = _ModelListTile(
        model: model,
        onSecondaryTap: (details) => openModelContextMenu(details, model),
      );
      children.add(child);
      children.add(const SizedBox(height: 12));
    }
    children.removeLast();
    return children;
  }

  Widget _buildProviderListView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var providers = providerViewModel.providers.value;
      if (providers.isEmpty) return const SizedBox();
      var borderSide = BorderSide(
        color: colors.borderFaint.withValues(alpha: 0.2),
      );
      var listView = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) =>
            _buildProviderTile(context, providers, index),
        itemCount: providers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      var syncButton = Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: AthenaTextButton(
          onTap: syncFromModelsDev,
          text: 'Sync models.dev',
        ),
      );
      return Container(
        decoration: BoxDecoration(border: Border(right: borderSide)),
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [syncButton, Expanded(child: listView)],
        ),
      );
    });
  }

  Widget _buildProviderTile(
    BuildContext context,
    List<ProviderEntity> providers,
    int index,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var provider = providers[index];
    var trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.enabled)
          Icon(
            HugeIcons.strokeRoundedToggleOn,
            size: 10,
            color: colors.iconSecondary,
          ),
        if (provider.isPreset) SizedBox(width: 4),
        if (provider.isPreset)
          Icon(
            HugeIcons.strokeRoundedCircleLock01,
            size: 10,
            color: colors.iconSecondary,
          ),
      ],
    );
    return DesktopMenuTile(
      active: this.index == index,
      label: provider.name,
      onSecondaryTap: (details) => openProviderContextMenu(details, provider),
      onTap: () => changeProvider(index),
      trailing: trailing,
    );
  }

  Widget _buildProviderView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var providers = providerViewModel.providers.value;
      if (providers.isEmpty) return const SizedBox();
      if (index >= providers.length) return const SizedBox();

      var nameTextStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );
      var nameText = Text(providers[index].name, style: nameTextStyle);
      var nameChildren = [
        nameText,
        Spacer(),
        AthenaSwitch(
          value: providers[index].enabled,
          onChanged: toggleProvider,
        ),
      ];
      var keyChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'API Key')),
        Expanded(
          child: AthenaInput(controller: keyController, onBlur: updateKey),
        ),
      ];
      var urlChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'API URL')),
        Expanded(
          child: AthenaInput(controller: urlController, onBlur: updateUrl),
        ),
      ];
      var modelTextStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
      var modelText = Text('Models', style: modelTextStyle);
      var addModelButton = AthenaTextButton(
        onTap: () => createModel(providers[index]),
        text: 'New',
      );
      var addModelChildren = [modelText, const Spacer(), addModelButton];

      var models = modelViewModel.models.value
          .where((m) => m.providerId == providers[index].id)
          .toList();
      var modelChildren = _buildModelListView(models);

      var listChildren = [
        Row(children: nameChildren),
        const SizedBox(height: 12),
        Row(children: keyChildren),
        const SizedBox(height: 12),
        Row(children: urlChildren),
        const SizedBox(height: 24),
        Row(children: addModelChildren),
        const SizedBox(height: 4),
        ...modelChildren,
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        children: listChildren,
      );
    });
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

class _ModelListTile extends StatefulWidget {
  final ModelEntity model;
  final void Function(TapUpDetails)? onSecondaryTap;
  const _ModelListTile({required this.model, this.onSecondaryTap});

  @override
  _ModelListTileState createState() => _ModelListTileState();
}

class _ModelListTileState extends State<_ModelListTile> {
  bool hover = false;

  bool get _showSubtitle {
    var visible = widget.model.releasedAt.isNotEmpty;
    visible |= widget.model.contextWindow > 0;
    visible |= widget.model.inputPrice.isNotEmpty;
    visible |= widget.model.outputPrice.isNotEmpty;
    visible |= widget.model.reasoning;
    visible |= widget.model.vision;
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var nameTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var nameText = Text(
      widget.model.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameTextStyle,
    );
    var nameChildren = [
      Flexible(child: nameText),
      if (widget.model.isPreset) SizedBox(width: 8),
      if (widget.model.isPreset)
        Icon(
          HugeIcons.strokeRoundedCircleLock01,
          size: 14,
          color: colors.iconSecondary,
        ),
      const SizedBox(width: 8),
      AthenaTag.small(text: widget.model.modelId),
    ];
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: colors.iconSecondary,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: colors.iconSecondary,
      size: 18,
    );
    var subtitleChildren = [
      _buildSubtitle(context),
      if (widget.model.reasoning) thinkIcon,
      if (widget.model.vision) visualIcon,
    ];
    var informationChildren = [
      Row(children: nameChildren),
      if (_showSubtitle) const SizedBox(height: 4),
      if (_showSubtitle) Row(spacing: 8, children: subtitleChildren),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    var paddedContent = Container(
      decoration: BoxDecoration(
        color: hover
            ? colors.surfaceButtonSecondary
            : colors.inputBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: column,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: paddedContent,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }

  Widget _buildSubtitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var releasedAt = widget.model.releasedAt;
    var contextWindow = widget.model.contextWindow;
    var inputPrice = widget.model.inputPrice;
    var outputPrice = widget.model.outputPrice;
    var parts = <String>[
      if (releasedAt.isNotEmpty) releasedAt,
      if (contextWindow > 0) formatContextWindow(contextWindow),
      if (inputPrice.isNotEmpty) inputPrice,
      if (outputPrice.isNotEmpty) outputPrice,
    ];
    var textStyle = TextStyle(
      color: colors.iconSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var text = Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    return Flexible(child: text);
  }
}
