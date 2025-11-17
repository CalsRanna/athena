import 'package:athena/entity/chat_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final ChatEntity chat;
  const ChatTile(this.chat, {super.key});

  @override
  Widget build(BuildContext context) {
    const shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(chat.title),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context),
      child: body,
    );
  }

  void handlePressed(BuildContext context) async {
    MobileChatRoute(chat: chat).push(context);
  }
}
