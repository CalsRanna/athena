import 'package:athena/entity/chat_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopChatSearchDecisionButton extends StatelessWidget {
  final ChatEntity chat;
  final void Function(bool)? onTap;
  const DesktopChatSearchDecisionButton({
    super.key,
    required this.chat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var iconData = HugeIcons.strokeRoundedNoInternet;
    if (chat.enableSearch) iconData = HugeIcons.strokeRoundedInternet;
    var icon = Icon(iconData, color: ColorUtil.FFFFFFFF, size: 24);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap?.call(!chat.enableSearch),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }
}
