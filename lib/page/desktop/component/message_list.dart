import 'package:athena/page/desktop/component/logo.dart';
import 'package:athena/page/desktop/component/message_tile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final messages = ref.watch(messagesNotifierProvider).value;
      if (messages == null) return const Logo();
      return ListView.builder(
        itemBuilder: (context, index) {
          final message = messages.reversed.elementAt(index);
          return MessageTile(
            message: message,
            // showToolbar: !(index == 0 && streaming),
            onRegenerated: () => handleRetry(context, index),
            onEdited: () => handleEdit(context, index),
            onDeleted: () => handleDelete(context, index),
          );
        },
        itemCount: messages.length,
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
        reverse: true,
      );
    });
    // return const Logo();
    // return Watcher((context, ref, child) {
    //   final chats = ref.watch(chatsCreator);
    //   final current = ref.watch(currentChatCreator);
    //   if (current == null || chats[current].messages.isEmpty) {
    //     return const Logo();
    //   }
    //   final chat = chats[current];
    //   final controller = context.ref.watch(scrollControllerCreator);
    //   final streaming = context.ref.watch(streamingCreator);
    //   return ListView.builder(
    //     controller: controller,
    //     itemBuilder: (context, index) {
    //       final message = chat.messages.reversed.elementAt(index);
    //       return MessageTile(
    //         message: message,
    //         showToolbar: !(index == 0 && streaming),
    //         onRegenerated: () => handleRetry(context, index),
    //         onEdited: () => handleEdit(context, index),
    //         onDeleted: () => handleDelete(context, index),
    //       );
    //     },
    //     itemCount: chat.messages.length,
    //     padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
    //     reverse: true,
    //   );
    // });
  }

  void handleDelete(BuildContext context, int index) {
    ChatProvider.of(context).delete(index);
  }

  void handleEdit(BuildContext context, int index) {
    ChatProvider.of(context).edit(index);
  }

  void handleRetry(BuildContext context, int index) {
    ChatProvider.of(context).retry(index);
  }
}
