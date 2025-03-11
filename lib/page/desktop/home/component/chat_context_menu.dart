import 'package:athena/widget/menu.dart';
import 'package:flutter/widgets.dart';

class DesktopChatContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final void Function()? onDestroyed;
  final void Function()? onImageExported;
  final void Function()? onRenamed;
  final double? width;

  const DesktopChatContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.onDestroyed,
    this.onImageExported,
    this.onRenamed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuOption(text: 'Rename', onTap: onRenamed),
      DesktopContextMenuOption(text: 'Delete', onTap: onDestroyed),
      DesktopContextMenuOption(text: 'Export Image', onTap: onImageExported),
    ];
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onBarrierTapped,
      width: 140,
      children: children,
    );
  }
}
