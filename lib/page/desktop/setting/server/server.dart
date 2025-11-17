import 'dart:convert';

import 'package:athena/entity/server_entity.dart';
import 'package:athena/page/desktop/setting/server/component/server_context_menu.dart';
import 'package:athena/page/desktop/setting/server/component/server_form_dialog.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server_view_model.dart';
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
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopSettingServerPage extends StatefulWidget {
  const DesktopSettingServerPage({super.key});

  @override
  State<DesktopSettingServerPage> createState() =>
      _DesktopSettingServerPageState();
}

class _DesktopSettingServerPageState extends State<DesktopSettingServerPage> {
  int index = 0;
  String result = '';
  final commandController = TextEditingController();
  final argumentsController = TextEditingController();
  final environmentsController = TextEditingController();

  late final viewModel = GetIt.instance<ServerViewModel>();

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildServerListView(),
      Expanded(child: _buildServerView()),
    ];
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(body: row);
  }

  Future<void> changeServer(int index) async {
    setState(() {
      this.index = index;
    });
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    commandController.text = servers[index].command;
    argumentsController.text = servers[index].arguments.join(' ');
    environmentsController.text = servers[index].environmentVariables.entries
        .map((e) => '${e.key}=${e.value}')
        .join('\n');

    // 获取工具列表
    await fetchTools();
  }

  Future<void> fetchTools() async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty || index >= servers.length) return;

    var server = servers[index];
    var updated = await viewModel.fetchServerTools(server);

    if (updated != null && updated.tools.isNotEmpty) {
      setState(() {
        result = 'Tools:\n${updated.tools.join('\n')}';
      });
    } else {
      setState(() {
        result = viewModel.error.value ?? 'No tools found';
      });
    }
  }

  Future<void> destroyServer(ServerEntity server) async {
    var confirmResult = await AthenaDialog.confirm(
      'Do you want to delete this server?',
    );
    if (confirmResult == true) {
      await viewModel.deleteServer(server);
      setState(() {
        index = 0;
        result = '';
      });
    }
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

  Future<void> listTools() async {
    AthenaDialog.loading();
    await fetchTools();
    AthenaDialog.dismiss();
  }

  void openServerFormDialog(ServerEntity server) async {
    AthenaDialog.show(DesktopServerFormDialog(server: server));
  }

  void showServerContextMenu(TapUpDetails details, ServerEntity server) {
    var contextMenu = DesktopServerContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroyServer(server),
      onEdited: () => openServerFormDialog(server),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  Future<void> toggleServer(bool value) async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(enabled: value);
    return viewModel.updateServer(copiedServer);
  }

  Future<void> updateArguments() async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    var args = argumentsController.text
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    var copiedServer = servers[index].copyWith(arguments: args);
    viewModel.updateServer(copiedServer);
  }

  Future<void> updateCommand() async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    var copiedServer = servers[index].copyWith(command: commandController.text);
    viewModel.updateServer(copiedServer);
  }

  Future<void> updateEnvironments() async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    var envMap = <String, String>{};
    for (var line in environmentsController.text.split('\n')) {
      var parts = line.split('=');
      if (parts.length == 2) {
        envMap[parts[0].trim()] = parts[1].trim();
      }
    }
    var copiedServer = servers[index].copyWith(environmentVariables: envMap);
    viewModel.updateServer(copiedServer);
  }

  Widget _buildServerListView() {
    return Watch((context) {
      var servers = viewModel.servers.value;
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
    });
  }

  Widget _buildServerTile(List<ServerEntity> servers, int index) {
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
    return Watch((context) {
      var servers = viewModel.servers.value;
      if (servers.isEmpty) return const SizedBox();
      var nameTextStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );
      var nameText = Text(servers[index].name, style: nameTextStyle);
      var nameChildren = [
        nameText,
        Spacer(),
        AthenaSwitch(value: servers[index].enabled, onChanged: toggleServer),
      ];
      var commandInput = AthenaInput(
        controller: commandController,
        onBlur: updateCommand,
      );
      var commandChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Command')),
        Expanded(child: commandInput),
      ];
      var argumentsInput = AthenaInput(
        controller: argumentsController,
        onBlur: updateArguments,
      );
      var argumentsChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Arguments')),
        Expanded(child: argumentsInput),
      ];
      var environmentsInput = AthenaInput(
        controller: environmentsController,
        onBlur: updateEnvironments,
      );
      var environmentsChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Environments')),
        Expanded(child: environmentsInput),
      ];
      var descriptionTextStyle = TextStyle(
        color: ColorUtil.FFC2C2C2,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );
      var description = servers.isNotEmpty && index < servers.length
          ? servers[index].description
          : '';
      var descriptionText = Text(
        description,
        style: descriptionTextStyle,
      );
      var toolsTextStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
      var toolsText = Text('Tools', style: toolsTextStyle);
      var listToolsButton = AthenaTextButton(
        onTap: listTools,
        text: 'List tools',
      );
      var listToolsChildren = [toolsText, const Spacer(), listToolsButton];
      var tools = jsonDecode(result.isEmpty ? '[]' : result);
      var toolsChildren = <Widget>[];
      for (var tool in tools) {
        toolsChildren.add(
          _ToolListTile(description: tool['description'], name: tool['name']),
        );
      }
      var listChildren = [
        Row(children: nameChildren),
        const SizedBox(height: 12),
        Row(children: commandChildren),
        const SizedBox(height: 12),
        Row(children: argumentsChildren),
        const SizedBox(height: 12),
        Row(children: environmentsChildren),
        if (description.isNotEmpty) const SizedBox(height: 12),
        if (description.isNotEmpty) descriptionText,
        const SizedBox(height: 12),
        Row(children: listToolsChildren),
        ...toolsChildren,
      ];
      var sliverPadding = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        sliver: SliverList(delegate: SliverChildListDelegate(listChildren)),
      );
      return CustomScrollView(slivers: [sliverPadding]);
    });
  }

  Future<void> _initState() async {
    var servers = viewModel.servers.value;
    if (servers.isEmpty) return;
    commandController.text = servers[index].command;
    argumentsController.text = servers[index].arguments.join(' ');
    environmentsController.text = servers[index].environmentVariables.entries
        .map((e) => '${e.key}=${e.value}')
        .join('\n');

    // 如果服务器有工具列表,显示它们
    if (servers[index].tools.isNotEmpty) {
      setState(() {
        result = 'Tools:\n${servers[index].tools.join('\n')}';
      });
    }
  }
}

class _ToolListTile extends StatefulWidget {
  final String description;
  final String name;
  const _ToolListTile({required this.description, required this.name});

  @override
  _ToolListTileState createState() => _ToolListTileState();
}

class _ToolListTileState extends State<_ToolListTile> {
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
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameTextStyle,
    );
    var nameChildren = [
      Flexible(child: nameText),
      SizedBox(width: 8),
      // AthenaTag.small(text: widget.model.value)
    ];
    var subtitleChildren = [_buildSubtitle()];
    var informationChildren = [
      Row(children: nameChildren),
      const SizedBox(height: 4),
      Row(spacing: 8, children: subtitleChildren),
    ];
    var informationWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: informationChildren,
    );
    var contentChildren = [Expanded(child: informationWidget)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: contentChildren),
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }

  Widget _buildSubtitle() {
    var textStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var text = Text(
      widget.description,
      // maxLines: 1,
      // overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    return Flexible(child: text);
  }
}
