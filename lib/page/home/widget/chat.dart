import 'package:athena/creator/chat.dart';
import 'package:athena/extension/date_time.dart';
import 'package:athena/provider/chat_provider.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  @override
  Widget build(BuildContext context) {
    return Watcher((context, ref, child) {
      final chats = ref.watch(chatsCreator);
      final theme = Theme.of(context);
      final textTheme = theme.textTheme;
      final labelMedium = textTheme.labelMedium;
      final labelSmall = textTheme.labelSmall;
      final colorScheme = theme.colorScheme;
      final surfaceVariant = colorScheme.surfaceVariant;
      final error = colorScheme.error;
      final onError = colorScheme.onError;
      final onSurfaceVariant = colorScheme.onSurfaceVariant;
      final outline = colorScheme.outline;
      return ListView.separated(
        itemCount: chats.length,
        itemBuilder: (context, index) => Card(
          elevation: 0,
          color: surfaceVariant,
          margin: EdgeInsets.zero,
          child: ClipRRect(
            child: Slidable(
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                children: [
                  SlidableAction(
                    backgroundColor: error,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    foregroundColor: onError,
                    label: '删除',
                    icon: Icons.delete_outline,
                    onPressed: (context) => handleDelete(index),
                  ),
                ],
              ),
              child: ListTile(
                subtitle: Text(
                  '${chats[index].messages.length}条对话',
                  style: labelMedium?.copyWith(color: onSurfaceVariant),
                ),
                title: Text(
                  chats[index].title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onSurfaceVariant),
                ),
                trailing: Text(
                  chats[index].messages.isNotEmpty
                      ? DateTime.fromMillisecondsSinceEpoch(
                          chats[index].updatedAt!,
                        ).toHumanReadableString()
                      : '',
                  style: labelSmall?.copyWith(color: outline),
                ),
                onTap: () => handleTap(index),
              ),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      );
    });
  }

  @override
  void didChangeDependencies() {
    final chats = context.ref.read(chatsCreator);
    if (chats.isEmpty) {
      ChatProvider.of(context).getChats();
    }
    super.didChangeDependencies();
  }

  void handleTap(int index) {
    ChatProvider.of(context).selectChat(index);
    final chats = context.ref.read(chatsCreator);
    context.push('/chat/${chats[index].id}');
  }

  void handleDelete(int index) async {
    ChatProvider.of(context).deleteChat(index);
  }
}
