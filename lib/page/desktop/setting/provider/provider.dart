import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/page/desktop/setting/provider/component/model_context_menu.dart';
import 'package:athena/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena/page/desktop/setting/provider/component/provider_context_menu.dart';
import 'package:athena/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/switch.dart';
import 'package:athena/widget/tag.dart';
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
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(body: row);
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

  void checkConnection(ModelEntity model) {
    modelViewModel.checkConnection(model);
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
    var contextMenu = DesktopModelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
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

  List<Widget> _buildModelListView(List<ModelEntity>? models) {
    if (models == null) return [const SizedBox()];
    if (models.isEmpty) return [const SizedBox()];
    List<Widget> children = [];
    for (var model in models) {
      var child = _ModelListTile(
        model: model,
        onSecondaryTap: (details) => openModelContextMenu(details, model),
        onTap: () => checkConnection(model),
      );
      children.add(child);
    }
    return children;
  }

  Widget _buildProviderListView() {
    return Watch((context) {
      var providers = providerViewModel.providers.value;
      if (providers.isEmpty) return const SizedBox();
      var borderSide = BorderSide(
        color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      );
      var listView = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) => _buildProviderTile(providers, index),
        itemCount: providers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      return Container(
        decoration: BoxDecoration(border: Border(right: borderSide)),
        width: 240,
        child: listView,
      );
    });
  }

  Widget _buildProviderTile(List<ProviderEntity> providers, int index) {
    var provider = providers[index];
    var tag = AthenaTag.small(fontSize: 6, text: 'ON');
    return DesktopMenuTile(
      active: this.index == index,
      label: provider.name,
      onSecondaryTap: (details) => openProviderContextMenu(details, provider),
      onTap: () => changeProvider(index),
      trailing: provider.enabled ? tag : null,
    );
  }

  Widget _buildProviderView() {
    return Watch((context) {
      var providers = providerViewModel.providers.value;
      if (providers.isEmpty) return const SizedBox();
      if (index >= providers.length) return const SizedBox();

      var nameTextStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
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
        color: ColorUtil.FFFFFFFF,
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
  final void Function()? onTap;
  const _ModelListTile({required this.model, this.onSecondaryTap, this.onTap});

  @override
  _ModelListTileState createState() => _ModelListTileState();
}

class _ModelListTileState extends State<_ModelListTile> {
  bool hover = false;

  bool get _showSubtitle {
    var visible = widget.model.releasedAt.isNotEmpty;
    visible |= widget.model.contextWindow.isNotEmpty;
    visible |= widget.model.inputPrice.isNotEmpty;
    visible |= widget.model.outputPrice.isNotEmpty;
    visible |= widget.model.reasoning;
    visible |= widget.model.vision;
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    var nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
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
      SizedBox(width: 8),
      AthenaTag.small(text: widget.model.modelId),
    ];
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var subtitleChildren = [
      _buildSubtitle(),
      if (widget.model.reasoning) thinkIcon,
      if (widget.model.vision) visualIcon,
    ];
    var informationChildren = [
      Row(children: nameChildren),
      if (_showSubtitle) const SizedBox(height: 4),
      if (_showSubtitle) Row(spacing: 8, children: subtitleChildren),
    ];
    var informationWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    var connectIcon = Icon(
      HugeIcons.strokeRoundedConnect,
      color: ColorUtil.FFE0E0E0,
      size: 20,
    );
    var paddedConnectIcon = Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: connectIcon,
    );
    var contentChildren = [
      Expanded(child: informationWidget),
      if (hover) paddedConnectIcon,
    ];
    var paddedContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: contentChildren),
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
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }

  Widget _buildSubtitle() {
    var releasedAt = widget.model.releasedAt;
    var context = widget.model.contextWindow;
    var inputPrice = widget.model.inputPrice;
    var outputPrice = widget.model.outputPrice;
    var parts = <String>[
      if (releasedAt.isNotEmpty) releasedAt,
      if (context.isNotEmpty) context,
      if (inputPrice.isNotEmpty) inputPrice,
      if (outputPrice.isNotEmpty) outputPrice,
    ];
    var textStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
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
