import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';

class DesktopSentinelContextMenu extends StatelessWidget {
  final Offset offset;
  final bool multiSelect;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  const DesktopSentinelContextMenu({
    super.key,
    required this.offset,
    this.multiSelect = false,
    this.onDestroyed,
    this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(
        text: 'Edit',
        onTap: onEdited,
        enabled: !multiSelect,
      ),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, children: children);
  }
}
