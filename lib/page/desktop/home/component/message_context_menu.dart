import 'package:athena/widget/card.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/widgets.dart';

class DesktopMessageContextMenu extends StatelessWidget {
  final void Function()? onCopied;
  final void Function()? onDestroyed;

  const DesktopMessageContextMenu({super.key, this.onCopied, this.onDestroyed});

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopContextMenuOption(text: 'Copy', onTap: onCopied),
      DesktopContextMenuOption(text: 'Delete', onTap: onDestroyed),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return ACard(child: column);
  }
}
