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
        itemBuilder: (context, index) => Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: ClipRRect(
            child: Slidable(
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                children: [
                  SlidableAction(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    label: '删除',
                    icon: Icons.delete_outline,
                    onPressed: (context) => handleDelete(chats![index].id),
                  ),
                ],
              ),
              child: ListTile(
                subtitle: Text(
                  '${chats![index].messages.length}条对话',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                title: Text(
                  chats[index].title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  chats[index].messages.isNotEmpty
                      ? DateTime.fromMillisecondsSinceEpoch(
                          chats[index].messages.last.createdAt!,
                        ).toString().substring(0, 16)
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                onTap: () => handleTap(chats[index].id),
              ),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
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
