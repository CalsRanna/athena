import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatTile extends ConsumerWidget {
  final Chat chat;
  const ChatTile(this.chat, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onTap: () => handlePressed(context, ref),
      child: body,
    );
  }

  void handlePressed(BuildContext context, WidgetRef ref) async {
    MobileChatRoute(chat: chat).push(context);
  }
}
