import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopChatSearchDecisionToggle extends StatelessWidget {
  final Chat chat;
  final void Function(bool)? onTap;
  const DesktopChatSearchDecisionToggle({
    super.key,
    required this.chat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var icon = HugeIcons.strokeRoundedNoInternet;
    if (chat.enableSearch) icon = HugeIcons.strokeRoundedInternet;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap?.call(!chat.enableSearch),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: Icon(icon)),
    );
  }
}
