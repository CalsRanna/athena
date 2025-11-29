import 'package:athena/widget/context_menu.dart';
import 'package:flutter/material.dart';

class DesktopModelContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onConnected;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  const DesktopModelContextMenu({
    super.key,
    required this.offset,
    this.onConnected,
    this.onDestroyed,
    this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(text: 'Connect', onTap: onConnected),
      DesktopContextMenuTile(text: 'Edit', onTap: onEdited),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, children: children);
  }
}
