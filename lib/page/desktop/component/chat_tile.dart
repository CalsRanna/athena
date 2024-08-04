import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    this.active = false,
    required this.chat,
    this.onDelete,
    this.onSelected,
  });

  final bool active;
  final Chat chat;
  final void Function()? onDelete;
  final void Function()? onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onPrimary = colorScheme.onPrimary;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? onPrimary.withOpacity(0.2) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Flexible(
              child: Text(
                chat.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: onPrimary, fontSize: 14),
              ),
            ),
            if (chat.model.isNotEmpty) ...[
              const SizedBox(width: 8),
              _Model(chat: chat),
            ],
          ],
        ),
      ),
    );
  }
}

class _Model extends StatelessWidget {
  const _Model({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onPrimary = colorScheme.onPrimary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: onPrimary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        chat.model + 'gpt-4o',
        style: TextStyle(
          color: onPrimary.withOpacity(0.2),
          fontSize: 8,
          height: 1,
        ),
      ),
    );
  }
}
