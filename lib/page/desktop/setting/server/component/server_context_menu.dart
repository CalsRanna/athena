import 'package:athena/widget/context_menu.dart';
import 'package:flutter/material.dart';

class DesktopServerContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  const DesktopServerContextMenu({
    super.key,
    required this.offset,
    this.onDestroyed,
    this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(text: 'Edit', onTap: onEdited),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed)
    ];
    return DesktopContextMenu(offset: offset, children: children);
  }
}
