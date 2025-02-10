import 'package:athena/page/desktop/setting/component/provider_form_dialog.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingProviderPage extends ConsumerStatefulWidget {
  const DesktopSettingProviderPage({super.key});

  @override
  ConsumerState<DesktopSettingProviderPage> createState() =>
      _DesktopSettingModelPageState();
}

class _ContextMenu extends StatelessWidget {
  final Offset offset;
  final Model model;
  final void Function()? onTap;
  const _ContextMenu({
    required this.offset,
    required this.model,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroySentinel(context),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroySentinel(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = modelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.deleteModel(model);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context) {
    ADialog.show(DesktopProviderFormDialog(model: model));
    onTap?.call();
  }
}

class _DesktopSettingModelPageState
    extends ConsumerState<DesktopSettingProviderPage> {
  OverlayEntry? entry;
  String model = '';
  int index = 0;
  final keyController = TextEditingController();
  final nameController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void navigateProvider() {
    DesktopSettingProviderSiliconFlowRoute().push(context);
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  void showContextMenu(TapUpDetails details, Model model) {
    var contextMenu = _ContextMenu(
      offset: details.globalPosition - Offset(200, 50),
      onTap: removeEntry,
      model: model,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
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

  Widget _buildProviderEnabledIndicator(bool enabled) {
    if (!enabled) return const SizedBox();
    return Container(
      decoration: ShapeDecoration(color: Colors.green, shape: StadiumBorder()),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text('ON', style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildProviderListView() {
    var provider = providerNotifierProvider;
    var providers = ref.watch(provider).valueOrNull;
    if (providers == null) return const SizedBox();
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var listView = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _itemBuilder(providers[index], index),
      itemCount: providers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    var placeholder = Center(
      child: Text('No providers', style: TextStyle(color: Colors.white)),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 200,
      child: providers.isNotEmpty ? listView : placeholder,
    );
  }

  Widget _buildProviderView() {
    var provider = providerNotifierProvider;
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
      ASwitch(value: providers[index].enabled, onChanged: (_) {})
    ];
    var keyChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Key')),
      Expanded(child: AInput(controller: TextEditingController()))
    ];
    var urlInput = AInput(controller: TextEditingController());
    var urlChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API URL')),
      Expanded(child: urlInput)
    ];
    const edgeInsets = EdgeInsets.symmetric(horizontal: 12.0);
    var checkButton = ASecondaryButton(
      child: Padding(padding: edgeInsets, child: Text('Check')),
    );
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
      modelText,
      const SizedBox(height: 4),
      // ...children,
      const SizedBox(height: 12),
      tipText
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: listChildren,
    );
  }

  Future<void> _initState() async {
    var provider = providerNotifierProvider;
    var providers = await ref.read(provider.future);
    if (providers.isEmpty) return;
    keyController.text = providers[index].key;
    nameController.text = providers[index].name;
  }

  Widget _itemBuilder(schema.Provider provider, int index) {
    var indicator = _buildProviderEnabledIndicator(provider.enabled);
    return DesktopMenuTile(
      active: this.index == index,
      label: provider.name,
      trailing: indicator,
    );
  }
}
