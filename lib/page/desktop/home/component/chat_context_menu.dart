import 'package:athena/schema/chat.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:flutter/widgets.dart';

class DesktopChatContextMenu extends StatelessWidget {
  final Chat chat;
  final Offset offset;
  final void Function()? onDestroyed;
  final void Function()? onExportedImage;
  final void Function()? onPinned;
  final void Function()? onRenamed;
  final double? width;

  const DesktopChatContextMenu({
    super.key,
    required this.chat,
    required this.offset,
    this.onDestroyed,
    this.onExportedImage,
    this.onPinned,
    this.onRenamed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    var pinText = chat.pinned ? 'Unpin' : 'Pin';
    var children = [
      DesktopContextMenuTile(text: pinText, onTap: onPinned),
      DesktopContextMenuTile(text: 'Rename', onTap: onRenamed),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
      DesktopContextMenuTile(text: 'Export Image', onTap: onExportedImage),
    ];
    return DesktopContextMenu(
      offset: offset,
      width: 140,
      children: children,
    );
  }
}
