import 'package:athena/provider/tool.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/view_model/tool.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingToolPage extends ConsumerStatefulWidget {
  const DesktopSettingToolPage({super.key});

  @override
  ConsumerState<DesktopSettingToolPage> createState() =>
      _DesktopSettingToolPageState();
}

class _DesktopSettingToolPageState
    extends ConsumerState<DesktopSettingToolPage> {
  int index = 0;
  final keyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildToolListView(), Expanded(child: _buildToolView())],
    );
    return AScaffold(body: row);
  }

  Future<void> changeTool(int index) async {
    setState(() {
      this.index = index;
    });
    var provider = toolsNotifierProvider;
    var tools = await ref.read(provider.future);
    if (tools.isEmpty) return;
    keyController.text = tools[index].key;
  }

  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> updateKey() async {
    var provider = toolsNotifierProvider;
    var tools = await ref.read(provider.future);
    if (tools.isEmpty) return;
    var copiedTool = tools[index].copyWith(key: keyController.text);
    ToolViewModel(ref).updateKey(copiedTool);
  }

  Widget _buildToolListView() {
    var provider = toolsNotifierProvider;
    var tools = ref.watch(provider).valueOrNull;
    if (tools == null) return const SizedBox();
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var listView = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _buildToolTile(tools, index),
      itemCount: tools.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 240,
      child: listView,
    );
  }

  Widget _buildToolTile(List<Tool> tools, int index) {
    return DesktopMenuTile(
      active: this.index == index,
      label: tools[index].name,
      onTap: () => changeTool(index),
    );
  }

  Widget _buildToolView() {
    var provider = toolsNotifierProvider;
    var tools = ref.watch(provider).valueOrNull;
    if (tools == null) return const SizedBox();
    if (tools.isEmpty) return const SizedBox();
    var nameTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var nameText = Text(tools[index].name, style: nameTextStyle);
    var nameChildren = [
      nameText,
      SizedBox(width: 4),
      Icon(HugeIcons.strokeRoundedLinkSquare02, color: Colors.white),
    ];
    var keyChildren = [
      SizedBox(width: 120, child: AFormTileLabel(title: 'API Key')),
      Expanded(child: AInput(controller: keyController, onBlur: updateKey))
    ];
    var descriptionTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var descriptionText = Text(
      tools[index].description,
      style: descriptionTextStyle,
    );
    var listChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: keyChildren),
      if (tools[index].description.isNotEmpty) const SizedBox(height: 12),
      if (tools[index].description.isNotEmpty) descriptionText
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: listChildren,
    );
  }

  Future<void> _initState() async {
    var provider = toolsNotifierProvider;
    var tools = await ref.read(provider.future);
    if (tools.isEmpty) return;
    keyController.text = tools[index].key;
  }
}
