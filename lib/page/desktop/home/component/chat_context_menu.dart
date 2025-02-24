import 'package:athena/widget/card.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/widgets.dart';

class DesktopChatContextMenu extends StatelessWidget {
  final void Function()? onDestroyed;
  final void Function()? onRenamed;

  const DesktopChatContextMenu({super.key, this.onDestroyed, this.onRenamed});

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuOption(text: 'Rename', onTap: onRenamed),
      DesktopContextMenuOption(text: 'Delete', onTap: onDestroyed),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return ACard(child: column);
  }
}
