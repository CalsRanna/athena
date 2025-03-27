import 'package:athena/widget/context_menu.dart';
import 'package:flutter/widgets.dart';

class DesktopMessageContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final void Function()? onCopied;
  final void Function()? onDestroyed;

  const DesktopMessageContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.onCopied,
    this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuTile(text: 'Copy', onTap: onCopied),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onBarrierTapped,
      children: children,
    );
  }
}
