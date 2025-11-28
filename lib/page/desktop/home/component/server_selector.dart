import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/entity/server_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopServerSelector extends StatelessWidget {
  final void Function(SentinelEntity)? onSelected;
  const DesktopServerSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var serverViewModel = GetIt.instance<ServerViewModel>();
      var enabledCount = serverViewModel.servers.value
          .where((s) => s.enabled)
          .length;

      var hugeIcon = HugeIcon(
        icon: HugeIcons.strokeRoundedTools,
        color: ColorUtil.FFFFFFFF,
        size: 24,
      );

      // 显示启用的服务器数量badge
      Widget iconWithBadge = hugeIcon;
      if (enabledCount > 0) {
        iconWithBadge = Stack(
          clipBehavior: Clip.none,
          children: [
            hugeIcon,
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ColorUtil.FF161616,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$enabledCount',
                  style: TextStyle(
                    color: ColorUtil.FFFFFFFF,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      }

      var mouseRegion = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: iconWithBadge,
      );
      return GestureDetector(onTap: openDialog, child: mouseRegion);
    });
  }

  void changeModel(SentinelEntity sentinel) {
    AthenaDialog.dismiss();
    onSelected?.call(sentinel);
  }

  void openDialog() {
    AthenaDialog.show(_SentinelSelectDialog(), barrierDismissible: true);
  }
}

class _DesktopServerSelectDialogTile extends StatefulWidget {
  final ServerEntity server;
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
      enabledSwitch,
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

class _SentinelSelectDialog extends StatelessWidget {
  const _SentinelSelectDialog();

  @override
  Widget build(BuildContext context) {
    final serverViewModel = GetIt.instance<ServerViewModel>();
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var servers = serverViewModel.servers.value;
      var child = _buildData(servers);
      var container = Container(
        decoration: boxDecoration,
        padding: EdgeInsets.all(8),
        child: child,
      );
      return UnconstrainedBox(child: container);
    });
  }

  void toggleServer(ServerEntity server) {
    final serverViewModel = GetIt.instance<ServerViewModel>();
    var copiedServer = server.copyWith(enabled: !server.enabled);
    serverViewModel.updateServer(copiedServer);
  }

  Widget _buildData(List<ServerEntity> servers) {
    if (servers.isEmpty) return _buildEmpty();
    List<Widget> children = servers
        .map((server) => _itemBuilder(server))
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _buildEmpty() {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: 520,
      child: Text('No servers', style: textStyle),
    );
  }

  Widget _itemBuilder(ServerEntity server) {
    return _DesktopServerSelectDialogTile(
      server: server,
      onTap: () => toggleServer(server),
    );
  }
}
