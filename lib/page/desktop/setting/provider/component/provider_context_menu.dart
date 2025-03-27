import 'package:athena/schema/provider.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:flutter/material.dart';

class DesktopProviderContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onDestroyed;
  final void Function()? onEdited;
  final void Function()? onTap;
  final Provider provider;
  const DesktopProviderContextMenu({
    super.key,
    required this.offset,
    this.onDestroyed,
    this.onEdited,
    this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuTile(text: 'Edit', onTap: onEdited);
    var deleteOption = DesktopContextMenuTile(
      text: 'Delete',
      onTap: onDestroyed,
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }
}
