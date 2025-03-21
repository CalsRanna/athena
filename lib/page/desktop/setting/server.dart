import 'package:athena/provider/server.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingServerPage extends ConsumerStatefulWidget {
  const DesktopSettingServerPage({super.key});

  @override
  ConsumerState<DesktopSettingServerPage> createState() =>
      _DesktopSettingServerPageState();
}

class _DesktopSettingServerPageState
    extends ConsumerState<DesktopSettingServerPage> {
  int index = 0;
  final commandController = TextEditingController();
  final argumentsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildServerListView(), Expanded(child: _buildServerView())],
    );
    return AthenaScaffold(body: row);
  }

  Future<void> changeServer(int index) async {
    setState(() {
      this.index = index;
    });
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    commandController.text = servers[index].command;
    argumentsController.text = servers[index].arguments;
  }

  @override
  void dispose() {
    commandController.dispose();
    argumentsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> updateArguments() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(
      arguments: argumentsController.text,
    );
    ServerViewModel(ref).updateServer(copiedServer);
  }

  Future<void> updateCommand() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(command: commandController.text);
    ServerViewModel(ref).updateServer(copiedServer);
  }

  Widget _buildServerListView() {
    var provider = serversNotifierProvider;
    var servers = ref.watch(provider).value;
    if (servers == null) return const SizedBox();
    var borderSide =
        BorderSide(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2));
    var listView = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _buildServerTile(servers, index),
      itemCount: servers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 240,
      child: listView,
    );
  }

  Widget _buildServerTile(List<Server> servers, int index) {
    return DesktopMenuTile(
      active: this.index == index,
      label: servers[index].name,
      onTap: () => changeServer(index),
    );
  }

  Widget _buildServerView() {
    var provider = serversNotifierProvider;
    var servers = ref.watch(provider).valueOrNull;
    if (servers == null) return const SizedBox();
    if (servers.isEmpty) return const SizedBox();
    var nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var nameText = Text(servers[index].name, style: nameTextStyle);
    var nameChildren = [
      nameText,
      SizedBox(width: 4),
      Icon(HugeIcons.strokeRoundedLinkSquare02, color: ColorUtil.FFFFFFFF),
    ];
    var commandInput = AthenaInput(
      controller: commandController,
      onBlur: updateCommand,
    );
    var commandChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Command')),
      Expanded(child: commandInput)
    ];
    var argumentsInput = AthenaInput(
      controller: argumentsController,
      onBlur: updateArguments,
    );
    var argumentsChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Arguments')),
      Expanded(child: argumentsInput)
    ];
    var descriptionTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var descriptionText = Text(
      servers[index].description,
      style: descriptionTextStyle,
    );
    var listChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: commandChildren),
      const SizedBox(height: 12),
      Row(children: argumentsChildren),
      if (servers[index].description.isNotEmpty) const SizedBox(height: 12),
      if (servers[index].description.isNotEmpty) descriptionText
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: listChildren,
    );
  }

  Future<void> _initState() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    commandController.text = servers[index].command;
    argumentsController.text = servers[index].arguments;
  }
}
