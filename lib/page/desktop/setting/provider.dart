import 'package:athena/page/desktop/setting/component/model_form_dialog.dart';
import 'package:athena/page/desktop/setting/component/provider_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/switch.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  OverlayEntry? entry;
  String model = '';
  int index = 0;
  final keyController = TextEditingController();
  final urlController = TextEditingController();

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
    return AScaffold(body: row);
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

  Future<void> destroyProvider(schema.Provider provider) async {
    entry?.remove();
    var notifier = ref.read(providersNotifierProvider.notifier);
    await notifier.destroy(provider);
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

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  Future<void> showModelContextMenu(TapUpDetails details, Model model) async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var contextMenu = _ModelContextMenu(
      offset: details.globalPosition - Offset(200, 50),
      onTap: removeEntry,
      model: model,
      provider: providers[index],
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    if (!mounted) return;
    Overlay.of(context).insert(entry!);
  }

  Future<void> showModelFormDialog() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    ADialog.show(DesktopModelFormDialog(provider: providers[index]));
  }

  void showProviderContextMenu(TapUpDetails details, schema.Provider provider) {
    if (provider.isPreset) return;
    var contextMenu = _ProviderContextMenu(
      offset: details.globalPosition - Offset(200, 50),
      onDestroyed: () => destroyProvider(provider),
      onEdited: () => showProviderFormDialog(provider),
      onTap: removeEntry,
      provider: provider,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  void showProviderFormDialog(schema.Provider provider) async {
    entry?.remove();
    ADialog.show(DesktopProviderFormDialog(provider: provider));
  }

  Future<void> toggleProvider(bool value) async {
    var provider = providersNotifierProvider;
    var providers = await ref.watch(provider.future);
    if (providers.isEmpty) return;
    var notifier = ref.read(provider.notifier);
    var copiedProvider = providers[index].copyWith(enabled: value);
    return notifier.updateProvider(copiedProvider);
  }

  Future<void> updateKey() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(key: keyController.text);
    var notifier = ref.read(provider.notifier);
    await notifier.updateProvider(copiedProvider);
  }

  Future<void> updateModel(Model model) async {
    setState(() {
      this.model = model.value;
    });
    var container = ProviderScope.containerOf(context);
    var provider = settingNotifierProvider;
    var notifier = container.read(provider.notifier);
    await notifier.updateModel(model.value);
  }

  Future<void> updateUrl() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(url: urlController.text);
    var notifier = ref.read(provider.notifier);
    await notifier.updateProvider(copiedProvider);
  }

  List<Widget> _buildModelListView(List<Model>? models) {
    if (models == null) return [const SizedBox()];
    if (models.isEmpty) return [const SizedBox()];
    List<Widget> children = [];
    for (var model in models) {
      var child = _ModelTile(
        onSecondaryTap: (details) => showModelContextMenu(details, model),
        model: model,
      );
      children.add(child);
    }
    return children;
  }

  Widget _buildProviderListView() {
    var provider = providersNotifierProvider;
    var providers = ref.watch(provider).valueOrNull;
    if (providers == null) return const SizedBox();
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var listView = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _buildProviderTile(providers, index),
      itemCount: providers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 200,
      child: listView,
    );
  }

  Widget _buildProviderTile(List<schema.Provider> providers, int index) {
    var provider = providers[index];
    return DesktopMenuTile(
      active: this.index == index,
      label: provider.name,
      onSecondaryTap: (details) => showProviderContextMenu(details, provider),
      onTap: () => changeProvider(index),
      trailing: _ProviderEnabledIndicator(provider: provider),
    );
  }

  Widget _buildProviderView() {
    var provider = providersNotifierProvider;
    var providers = ref.watch(provider).valueOrNull;
    if (providers == null) return const SizedBox();
    if (providers.isEmpty) return const SizedBox();
    var nameTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var nameText = Text(providers[index].name, style: nameTextStyle);
    var nameChildren = [
      nameText,
      SizedBox(width: 4),
      Icon(HugeIcons.strokeRoundedLinkSquare02, color: Colors.white),
      Spacer(),
      ASwitch(value: providers[index].enabled, onChanged: toggleProvider)
    ];
    var keyChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Key')),
      Expanded(child: AInput(controller: keyController, onBlur: updateKey))
    ];
    var urlChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API URL')),
      Expanded(child: AInput(controller: urlController, onBlur: updateUrl))
    ];
    var checkButton = ASecondaryButton.small(child: Text('Check'));
    var checkChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'Connect')),
      Spacer(),
      checkButton
    ];
    var modelTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    var modelText = Text('Models', style: modelTextStyle);
    var addModelButton = ASecondaryButton.small(
      onTap: showModelFormDialog,
      child: Text('Add Model'),
    );
    var addModelChildren = [modelText, const Spacer(), addModelButton];
    var modelProvider = modelsForNotifierProvider(providers[index].id);
    var models = ref.watch(modelProvider).valueOrNull;
    var modelChildren = _buildModelListView(models);
    var tipTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var tipText = Text(
      '查看${providers[index].name}文档和模型获取更多详情',
      style: tipTextStyle,
    );
    var listChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: keyChildren),
      const SizedBox(height: 12),
      Row(children: urlChildren),
      const SizedBox(height: 12),
      Row(children: checkChildren),
      const SizedBox(height: 24),
      Row(children: addModelChildren),
      const SizedBox(height: 4),
      ...modelChildren,
      if (providers[index].isPreset) const SizedBox(height: 12),
      if (providers[index].isPreset) tipText
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

class _ModelContextMenu extends StatelessWidget {
  final Offset offset;
  final Model model;
  final void Function()? onTap;
  final schema.Provider provider;
  const _ModelContextMenu({
    required this.offset,
    required this.model,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => showModelFormDialog(context),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroyModel(context),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroyModel(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var modelsProvider = modelsForNotifierProvider(provider.id);
    var notifier = container.read(modelsProvider.notifier);
    notifier.deleteModel(model);
    onTap?.call();
  }

  void showModelFormDialog(BuildContext context) {
    ADialog.show(DesktopModelFormDialog(provider: provider, model: model));
    onTap?.call();
  }
}

class _ModelTile extends StatelessWidget {
  final void Function(TapUpDetails)? onSecondaryTap;
  final Model model;
  const _ModelTile({this.onSecondaryTap, required this.model});

  @override
  Widget build(BuildContext context) {
    var nameTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var nameText = Text(model.name, style: nameTextStyle);
    var nameChildren = [
      nameText,
      SizedBox(width: 8),
      ATag.small(text: model.value)
    ];
    var subtitleTextStyle = TextStyle(
      color: Color(0xFFE0E0E0),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var releasedAtText = Text(
      'Released at ${model.releasedAt}',
      style: subtitleTextStyle,
    );
    var inputPriceText = Text(
      'input ${model.inputPrice}',
      style: subtitleTextStyle,
    );
    var outputPriceText = Text(
      'input ${model.outputPrice}',
      style: subtitleTextStyle,
    );
    var children = [
      if (model.releasedAt.isNotEmpty) releasedAtText,
      if (model.inputPrice.isNotEmpty) inputPriceText,
      if (model.outputPrice.isNotEmpty) outputPriceText,
    ];
    var informationChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 4),
      Row(spacing: 4, children: children),
    ];
    var informationWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: informationWidget,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: padding,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onSecondaryTap,
      child: mouseRegion,
    );
  }
}

class _ProviderContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  final void Function()? onTap;
  final schema.Provider provider;
  const _ProviderContextMenu({
    required this.offset,
    this.onDestroyed,
    this.onEdited,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(text: 'Edit', onTap: onEdited);
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: onDestroyed,
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }
}

class _ProviderEnabledIndicator extends StatelessWidget {
  final schema.Provider provider;
  const _ProviderEnabledIndicator({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.enabled) return const SizedBox();
    return Container(
      decoration: ShapeDecoration(color: Colors.green, shape: StadiumBorder()),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text('ON', style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
