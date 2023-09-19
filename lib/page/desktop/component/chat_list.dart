import 'dart:io';

import 'package:athena/creator/chat.dart';
import 'package:athena/main.dart';
import 'package:athena/page/desktop/component/chat_tile.dart';
import 'package:athena/page/desktop/component/create_button.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class ChatList extends StatelessWidget {
  const ChatList({super.key});

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
                  onDelete: () => handleDelete(context, index),
                  onSelected: () => handleSelect(context, index),
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

  void handleDelete(BuildContext context, int index) async {
    final ref = context.ref;
    var chats = ref.read(chatsCreator);
    final chat = chats[index];
    try {
      await isar.writeTxn(() async {
        await isar.chats.delete(chat.id);
      });
      chats = await isar.chats.where().findAll();
      chats = chats.map((chat) {
        return chat.withGrowableMessages();
      }).toList();
      ref.set(chatsCreator, [...chats]);
      ref.set(currentChatCreator, null);
    } catch (error) {
      Logger().e(error);
    }
  }

  void handleSelect(BuildContext context, int index) {
    // scrollToBottom();
    context.ref.set(currentChatCreator, index);
  }
}
