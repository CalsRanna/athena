import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';

class DesktopSkillContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onDestroyed;
  const DesktopSkillContextMenu({
    super.key,
    required this.offset,
    this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, children: children);
  }
}
