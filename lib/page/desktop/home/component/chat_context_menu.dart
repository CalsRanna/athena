import 'package:athena/widget/menu.dart';
import 'package:flutter/widgets.dart';

class DesktopChatContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final void Function()? onDestroyed;
  final void Function()? onRenamed;

  const DesktopChatContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.onDestroyed,
    this.onRenamed,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuOption(text: 'Rename', onTap: onRenamed),
      DesktopContextMenuOption(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onBarrierTapped,
      children: children,
    );
  }
}
