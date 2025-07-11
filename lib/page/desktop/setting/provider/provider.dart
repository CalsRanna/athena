import 'package:athena/page/desktop/setting/provider/component/model_context_menu.dart';
import 'package:athena/page/desktop/setting/provider/component/model_form_dialog.dart';
import 'package:athena/page/desktop/setting/provider/component/provider_context_menu.dart';
import 'package:athena/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/view_model/provider.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingProviderPage extends ConsumerStatefulWidget {
  const DesktopSettingProviderPage({super.key});

  @override
  ConsumerState<DesktopSettingProviderPage> createState() =>
      _DesktopSettingProviderPageState();
}

class _DesktopSettingProviderPageState
    extends ConsumerState<DesktopSettingProviderPage> {
  String model = '';
  int index = 0;
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  late final modelViewModel = ModelViewModel(ref);
  late final providerViewModel = ProviderViewModel(ref);

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
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    keyController.text = providers[index].key;
    urlController.text = providers[index].url;
  }

  void checkConnection(Model model) {
    final viewModel = ModelViewModel(ref);
    viewModel.checkConnection(model);
  }

  void createModel(Provider provider) {
    AthenaDialog.show(DesktopModelFormDialog(provider: provider));
  }

  Future<void> destroyProvider(Provider provider) async {
    await providerViewModel.destroyProvider(provider);
    setState(() {
      index = 0;
    });
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> editModel(Model model) async {
    var providerProvider = providerNotifierProvider(model.providerId);
    var provider = await ref.read(providerProvider.future);
    AthenaDialog.show(DesktopModelFormDialog(provider: provider, model: model));
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> openModelContextMenu(TapUpDetails details, Model model) async {
    var contextMenu = DesktopModelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => modelViewModel.destroyModel(model),
      onEdited: () => editModel(model),
    );
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void openProviderContextMenu(TapUpDetails details, Provider provider) {
    if (provider.isPreset) return;
    var contextMenu = DesktopProviderContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyProvider(provider),
      onEdited: () => openProviderFormDialog(provider),
    );
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void openProviderFormDialog(Provider provider) async {
    AthenaDialog.show(DesktopProviderFormDialog(provider: provider));
  }

  Future<void> toggleProvider(bool value) async {
    var provider = providersNotifierProvider;
    var providers = await ref.watch(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(enabled: value);
    return providerViewModel.updateProvider(copiedProvider);
  }

  Future<void> updateKey() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(key: keyController.text);
    await providerViewModel.updateProvider(copiedProvider);
  }

  Future<void> updateUrl() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(url: urlController.text);
    await providerViewModel.updateProvider(copiedProvider);
  }

  List<Widget> _buildModelListView(List<Model>? models) {
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
    var provider = providersNotifierProvider;
    var providers = ref.watch(provider).valueOrNull;
    if (providers == null) return const SizedBox();
    var borderSide =
        BorderSide(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2));
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
  }

  Widget _buildProviderTile(List<Provider> providers, int index) {
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
    var provider = providersNotifierProvider;
    var providers = ref.watch(provider).valueOrNull;
    if (providers == null) return const SizedBox();
    if (providers.isEmpty) return const SizedBox();
    var nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var nameText = Text(providers[index].name, style: nameTextStyle);
    var nameChildren = [
      nameText,
      Spacer(),
      AthenaSwitch(value: providers[index].enabled, onChanged: toggleProvider)
    ];
    var keyChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'API Key')),
      Expanded(child: AthenaInput(controller: keyController, onBlur: updateKey))
    ];
    var urlChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'API URL')),
      Expanded(child: AthenaInput(controller: urlController, onBlur: updateUrl))
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
    var modelProvider = modelsForNotifierProvider(providers[index].id);
    var models = ref.watch(modelProvider).valueOrNull;
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
  }

  Future<void> _initState() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    keyController.text = providers[index].key;
    urlController.text = providers[index].url;
  }
}

class _ModelListTile extends StatefulWidget {
  final Model model;
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
    visible |= widget.model.context.isNotEmpty;
    visible |= widget.model.inputPrice.isNotEmpty;
    visible |= widget.model.outputPrice.isNotEmpty;
    visible |= widget.model.supportReasoning;
    visible |= widget.model.supportVisual;
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
      AthenaTag.small(text: widget.model.value)
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
      if (widget.model.supportReasoning) thinkIcon,
      if (widget.model.supportVisual) visualIcon,
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
    var context = widget.model.context;
    var inputPrice = widget.model.inputPrice;
    var outputPrice = widget.model.outputPrice;
    var parts = [
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
