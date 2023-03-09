import 'package:athena/creator/chat.dart';
import 'package:athena/creator/global.dart';
import 'package:athena/model/chat.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  @override
  Widget build(BuildContext context) {
    return EmitterWatcher<List<Chat>?>(
      emitter: chatsEmitter,
      placeholder: const SizedBox(),
      builder: (context, chats) => ListView.separated(
        itemCount: chats?.length ?? 0,
        itemBuilder: (context, index) => Slidable(
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                label: '删除',
                icon: Icons.delete_outline,
                onPressed: (context) => handleDelete(chats![index].id),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              height: 56,
              width: 56,
              child: Center(
                child: Text(
                  chats![index].title?.substring(0, 1).toUpperCase() ?? '',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            title: Text(
              chats[index].title ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              DateTime.fromMillisecondsSinceEpoch(
                      chats[index].messages.last.createdAt!)
                  .toString()
                  .substring(0, 19),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            onTap: () => handleTap(chats[index].id),
          ),
        ),
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 72,
        ),
      ),
    );
  }

  void handleTap(int id) {
    context.push('/chat/$id');
  }

  void handleDelete(int id) async {
    try {
      final ref = context.ref;
      final isar = await ref.read(isarEmitter);
      await isar.writeTxn(() async {
        await isar.chats.delete(id);
      });
      final chats = await isar.chats.where().findAll();
      ref.emit(chatsEmitter, chats);
    } catch (error) {
      Logger().e(error);
    }
  }
}
