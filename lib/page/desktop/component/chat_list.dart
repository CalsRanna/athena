import 'dart:io';

import 'package:athena/creator/chat.dart';
import 'package:athena/page/desktop/component/chat_tile.dart';
import 'package:athena/page/desktop/component/create_button.dart';
import 'package:athena/provider/chat_provider.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(8),
      width: 272,
      child: Column(
        children: [
          if (Platform.isMacOS) const SizedBox(height: 20),
          const CreateButton(),
          const SizedBox(height: 8),
          Expanded(child: Watcher((context, ref, child) {
            final chats = ref.watch(chatsCreator);
            final current = ref.watch(currentChatCreator);
            return ListView.separated(
              itemBuilder: (context, index) {
                return ChatTile(
                  active: index == current,
                  chat: chats[index],
                  onDelete: () => handleDelete(index),
                  onSelected: () => handleSelect(index),
                );
              },
              itemCount: chats.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
            );
          })),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    ChatProvider.of(context).getChats();
    super.didChangeDependencies();
  }

  void handleDelete(int index) async {
    ChatProvider.of(context).deleteChat(index);
  }

  void handleSelect(int index) {
    ChatProvider.of(context).selectChat(index);
  }
}
