import 'package:athena/entity/chat_entity.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:flutter/widgets.dart';

class DesktopChatContextMenu extends StatelessWidget {
  final ChatEntity chat;
  final bool multiSelect;
  final Offset offset;
  final void Function()? onAutoRenamed;
  final void Function()? onDestroyed;
  final void Function()? onExportedImage;
  final void Function()? onManualRenamed;
  final void Function()? onPinned;
  final int selectedCount;
  final double? width;

  const DesktopChatContextMenu({
    super.key,
    required this.chat,
    this.multiSelect = false,
    required this.offset,
    this.onAutoRenamed,
    this.onDestroyed,
    this.onExportedImage,
    this.onManualRenamed,
    this.onPinned,
    this.selectedCount = 1,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    var pinText = chat.pinned ? 'Unpin' : 'Pin';
    var renameSubmenu = DesktopContextMenuTileWithSubmenu(
      text: 'Rename',
      enabled: !multiSelect,
      submenuItems: [
        DesktopContextMenuSubItem(text: 'Auto Rename', onTap: onAutoRenamed),
        DesktopContextMenuSubItem(
          text: 'Manual Rename',
          onTap: onManualRenamed,
        ),
      ],
    );
    var children = [
      DesktopContextMenuTile(
        text: pinText,
        onTap: onPinned,
        enabled: !multiSelect,
      ),
      renameSubmenu,
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
      DesktopContextMenuTile(
        text: 'Export Image',
        onTap: onExportedImage,
        enabled: !multiSelect,
      ),
    ];
    return DesktopContextMenu(offset: offset, width: 140, children: children);
  }
}
