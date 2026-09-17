import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';

/// 经验条目右键菜单：归档/恢复与删除（经验不支持手工增改）。
class DesktopExperienceContextMenu extends StatelessWidget {
  final Offset offset;
  final bool multiSelect;
  final bool canArchive;
  final bool isArchived;
  final void Function()? onToggledStatus;
  final void Function()? onDestroyed;

  const DesktopExperienceContextMenu({
    super.key,
    required this.offset,
    this.multiSelect = false,
    this.canArchive = true,
    required this.isArchived,
    this.onToggledStatus,
    this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(
        text: !multiSelect && isArchived ? 'Restore' : 'Archive',
        onTap: onToggledStatus,
        enabled: !multiSelect || canArchive,
      ),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, children: children);
  }
}
