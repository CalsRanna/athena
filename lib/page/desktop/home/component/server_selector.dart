import 'package:athena/provider/mcp.dart';
import 'package:athena/provider/server.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/switch.dart';
import 'package:dart_mcp/client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopServerSelector extends ConsumerWidget {
  final void Function(Sentinel)? onSelected;
  const DesktopServerSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedTools,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    var provider = mcpConnectionsNotifierProvider;
    var state = ref.watch(provider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      AsyncLoading() => _buildLoading(),
      AsyncError() => _buildError(),
      _ => const SizedBox(),
    };
    var badge = Badge(
      backgroundColor: ColorUtil.FF616161,
      label: child,
      child: hugeIcon,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: badge,
    );
    return GestureDetector(onTap: openDialog, child: mouseRegion);
  }

  void changeModel(Sentinel sentinel) {
    AthenaDialog.dismiss();
    onSelected?.call(sentinel);
  }

  void openDialog() {
    AthenaDialog.show(_SentinelSelectDialog(), barrierDismissible: true);
  }

  Widget _buildData(Map<String, ServerConnection> connections) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 8,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    return Text(connections.length.toString(), style: textStyle);
  }

  Widget _buildError() {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 8,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    return Text('0', style: textStyle);
  }

  Widget _buildLoading() {
    var circularProgressIndicator = CircularProgressIndicator(
      color: ColorUtil.FFFFFFFF,
      strokeWidth: 1,
    );
    return SizedBox(width: 8, height: 8, child: circularProgressIndicator);
  }
}

class _DesktopServerSelectDialogTile extends StatefulWidget {
  final Server server;
  final void Function()? onTap;
  const _DesktopServerSelectDialogTile({required this.server, this.onTap});

  @override
  State<_DesktopServerSelectDialogTile> createState() =>
      _DesktopServerSelectDialogTileState();
}

class _DesktopServerSelectDialogTileState
    extends State<_DesktopServerSelectDialogTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? ColorUtil.FF616161 : null,
    );
    var enabledSwitch = AthenaSwitch(
      onChanged: (value) => widget.onTap?.call(),
      value: widget.server.enabled,
    );
    var children = [
      Expanded(child: Text(widget.server.name, style: textStyle)),
      enabledSwitch
    ];
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: children),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}

class _SentinelSelectDialog extends ConsumerWidget {
  const _SentinelSelectDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serversNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(8),
      child: child,
    );
    return UnconstrainedBox(child: container);
  }

  void toggleServer(WidgetRef ref, Server server) {
    var viewModel = ServerViewModel(ref);
    var copiedServer = server.copyWith(enabled: !server.enabled);
    viewModel.updateServer(copiedServer);
  }

  Widget _buildData(WidgetRef ref, List<Server> servers) {
    if (servers.isEmpty) return const SizedBox();
    List<Widget> children =
        servers.map((server) => _itemBuilder(ref, server)).toList();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _itemBuilder(WidgetRef ref, Server server) {
    return _DesktopServerSelectDialogTile(
      server: server,
      onTap: () => toggleServer(ref, server),
    );
  }
}
