import 'package:athena/page/desktop/component/chat_tile.dart';
import 'package:athena/page/desktop/component/profile.dart';
import 'package:athena/provider/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatList extends StatelessWidget {
  const ChatList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: const Column(
        children: [
          SizedBox(height: 50),
          _Search(),
          SizedBox(height: 8),
          Expanded(child: _List()),
          SizedBox(height: 8),
          ProfileTile(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final chat = ref.watch(chatNotifierProvider);
      final chats = ref.watch(chatsNotifierProvider).value;
      if (chats == null) return const SizedBox();
      return ListView.separated(
        itemBuilder: (context, index) {
          return ChatTile(
            active: chats[index].id == chat.id,
            chat: chats[index],
            onSelected: () => handleSelect(ref, index),
          );
        },
        itemCount: chats.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 8);
        },
      );
    });
  }

  void handleSelect(WidgetRef ref, int index) {
    final notifier = ref.read(chatsNotifierProvider.notifier);
    notifier.select(index);
  }
}

class _Search extends StatelessWidget {
  const _Search();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
            size: 16,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              cursorColor: Theme.of(context).colorScheme.onPrimary,
              decoration: InputDecoration.collapsed(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                  fontSize: 14,
                  height: 16 / 14,
                ),
              ),
              style: const TextStyle(fontSize: 14, height: 16 / 14),
            ),
          ),
        ],
      ),
    );
  }
}
