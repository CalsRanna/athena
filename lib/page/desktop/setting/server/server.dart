import 'package:athena/page/desktop/setting/server/component/server_context_menu.dart';
import 'package:athena/page/desktop/setting/server/component/server_form_dialog.dart';
import 'package:athena/provider/server.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server.dart';
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
class DesktopSettingServerPage extends ConsumerStatefulWidget {
  const DesktopSettingServerPage({super.key});

  @override
  ConsumerState<DesktopSettingServerPage> createState() =>
      _DesktopSettingServerPageState();
}

class _DesktopSettingServerPageState
    extends ConsumerState<DesktopSettingServerPage> {
  OverlayEntry? entry;
  int index = 0;
  String result = '';
  final commandController = TextEditingController();
  final argumentsController = TextEditingController();
  final environmentsController = TextEditingController();

  late final viewModel = ServerViewModel(ref);

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
      result = '';
    });
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    commandController.text = servers[index].command;
    argumentsController.text = servers[index].arguments;
    environmentsController.text = servers[index].environments;
  }

  Future<void> debug() async {
    if (commandController.text.isEmpty) return;
    AthenaDialog.loading();
    var result = await viewModel.debugCommand(commandController.text);
    setState(() {
      this.result = result;
    });
    AthenaDialog.dismiss();
  }

  Future<void> destroyServer(Server server) async {
    entry?.remove();
    await viewModel.destroyServer(server);
    setState(() {
      index = 0;
    });
  }

  @override
  void dispose() {
    commandController.dispose();
    argumentsController.dispose();
    environmentsController.dispose();
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

  void showServerContextMenu(TapUpDetails details, Server server) {
    var contextMenu = DesktopServerContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyServer(server),
      onEdited: () => showServerFormDialog(server),
      onTap: removeEntry,
      server: server,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  void showServerFormDialog(Server server) async {
    entry?.remove();
    AthenaDialog.show(DesktopServerFormDialog(server: server));
  }

  Future<void> toggleServer(bool value) async {
    var provider = serversNotifierProvider;
    var servers = await ref.watch(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(enabled: value);
    return viewModel.updateServer(copiedServer);
  }

  Future<void> updateArguments() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(
      arguments: argumentsController.text,
    );
    viewModel.updateServer(copiedServer);
  }

  Future<void> updateCommand() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(command: commandController.text);
    viewModel.updateServer(copiedServer);
  }

  Future<void> updateEnvironments() async {
    var provider = serversNotifierProvider;
    var servers = await ref.read(provider.future);
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(
      environments: environmentsController.text,
    );
    viewModel.updateServer(copiedServer);
  }

  Widget _buildServerListView() {
    var provider = serversNotifierProvider;
    var servers = ref.watch(provider).value;
    if (servers == null) return const SizedBox();
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    Widget child = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _buildServerTile(servers, index),
      itemCount: servers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    if (servers.isEmpty) {
      var textStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
        decoration: TextDecoration.none,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );
      child = Center(child: Text('No MCP Servers', style: textStyle));
    }
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 240,
      child: child,
    );
  }

  Widget _buildServerTile(List<Server> servers, int index) {
    var tag = AthenaTag.small(fontSize: 6, text: 'ON');
    var server = servers[index];
    return DesktopMenuTile(
      active: this.index == index,
      label: server.name,
      onSecondaryTap: (details) => showServerContextMenu(details, server),
      onTap: () => changeServer(index),
      trailing: server.enabled ? tag : null,
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
      Spacer(),
      AthenaSwitch(value: servers[index].enabled, onChanged: toggleServer),
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
    var environmentsInput = AthenaInput(
      controller: environmentsController,
      onBlur: updateEnvironments,
    );
    var environmentsChildren = [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Environments')),
      Expanded(child: environmentsInput)
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
    var debugTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    var debugText = Text('Debug command', style: debugTextStyle);
    var debugButton = AthenaTextButton(onTap: debug, text: 'Debug');
    var debugChildren = [debugText, const Spacer(), debugButton];
    var resultTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var listChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: commandChildren),
      const SizedBox(height: 12),
      Row(children: argumentsChildren),
      const SizedBox(height: 12),
      Row(children: environmentsChildren),
      if (servers[index].description.isNotEmpty) const SizedBox(height: 12),
      if (servers[index].description.isNotEmpty) descriptionText,
      const SizedBox(height: 12),
      Row(children: debugChildren),
      Text(result, style: resultTextStyle),
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
    environmentsController.text = servers[index].environments;
  }
}
