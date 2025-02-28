import 'package:athena/page/desktop/setting/component/model_form_dialog.dart';
import 'package:athena/page/desktop/setting/component/provider_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/view_model/provider.dart';
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
  OverlayEntry? entry;
  String model = '';
  int index = 0;
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  late final viewModel = ProviderViewModel(ref);

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

  Future<void> checkConnection(Model model) async {
    final viewModel = ModelViewModel(ref);
    var result = await viewModel.checkConnection(model);
    AthenaDialog.message(result);
  }

  Future<void> destroyProvider(Provider provider) async {
    entry?.remove();
    await viewModel.destroyProvider(provider);
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
      offset: details.globalPosition - Offset(240, 50),
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
    AthenaDialog.show(DesktopModelFormDialog(provider: providers[index]));
  }

  void showProviderContextMenu(TapUpDetails details, Provider provider) {
    if (provider.isPreset) return;
    var contextMenu = _ProviderContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyProvider(provider),
      onEdited: () => showProviderFormDialog(provider),
      onTap: removeEntry,
      provider: provider,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  void showProviderFormDialog(Provider provider) async {
    entry?.remove();
    AthenaDialog.show(DesktopProviderFormDialog(provider: provider));
  }

  Future<void> toggleProvider(bool value) async {
    var provider = providersNotifierProvider;
    var providers = await ref.watch(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(enabled: value);
    return viewModel.updateProvider(copiedProvider);
  }

  Future<void> updateKey() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(key: keyController.text);
    await viewModel.updateProvider(copiedProvider);
  }

  Future<void> updateUrl() async {
    var provider = providersNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    var copiedProvider = providers[index].copyWith(url: urlController.text);
    await viewModel.updateProvider(copiedProvider);
  }

  List<Widget> _buildModelListView(List<Model>? models) {
    if (models == null) return [const SizedBox()];
    if (models.isEmpty) return [const SizedBox()];
    List<Widget> children = [];
    for (var model in models) {
      var child = _ModelTile(
        onSecondaryTap: (details) => showModelContextMenu(details, model),
        onTap: () => checkConnection(model),
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
      onSecondaryTap: (details) => showProviderContextMenu(details, provider),
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
      SizedBox(width: 4),
      Icon(HugeIcons.strokeRoundedLinkSquare02, color: ColorUtil.FFFFFFFF),
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
      onTap: showModelFormDialog,
      text: 'New',
    );
    var addModelChildren = [modelText, const Spacer(), addModelButton];
    var modelProvider = modelsForNotifierProvider(providers[index].id);
    var models = ref.watch(modelProvider).valueOrNull;
    var modelChildren = _buildModelListView(models);
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
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

class _ModelContextMenu extends ConsumerWidget {
  final Offset offset;
  final Model model;
  final void Function()? onTap;
  final Provider provider;
  const _ModelContextMenu({
    required this.offset,
    required this.model,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => showModelFormDialog(context),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroyModel(context, ref),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroyModel(BuildContext context, WidgetRef ref) {
    ModelViewModel(ref).destroyModel(model);
    onTap?.call();
  }

  void showModelFormDialog(BuildContext context) {
    AthenaDialog.show(DesktopModelFormDialog(provider: provider, model: model));
    onTap?.call();
  }
}

class _ModelTile extends StatefulWidget {
  final void Function(TapUpDetails)? onSecondaryTap;
  final void Function()? onTap;
  final Model model;
  const _ModelTile({this.onSecondaryTap, this.onTap, required this.model});

  @override
  _ModelTileState createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  bool hover = false;

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
    var functionCallIcon = Icon(
      HugeIcons.strokeRoundedFunctionCircle,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var visualRecognitionIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var subtitleChildren = [
      _buildSubtitle(),
      if (widget.model.supportFunctionCall) functionCallIcon,
      if (widget.model.supportThinking) thinkIcon,
      if (widget.model.supportVisualRecognition) visualRecognitionIcon,
    ];
    var informationChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 4),
      Row(spacing: 8, children: subtitleChildren),
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
    var inputPrice = widget.model.inputPrice;
    var outputPrice = widget.model.outputPrice;
    var maxToken = widget.model.maxToken;
    var maxTokenString = '${widget.model.maxToken ~/ 1024}K';
    if (maxToken > 1024 * 1024) {
      maxTokenString = '${widget.model.maxToken ~/ (1024 * 1024)}M';
    }
    var parts = [
      if (releasedAt.isNotEmpty) 'Released at ${widget.model.releasedAt}',
      if (inputPrice.isNotEmpty) 'Input ${widget.model.inputPrice}',
      if (outputPrice.isNotEmpty) 'Output ${widget.model.outputPrice}',
      if (maxToken > 0) maxTokenString,
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

class _ProviderContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  final void Function()? onTap;
  final Provider provider;
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
