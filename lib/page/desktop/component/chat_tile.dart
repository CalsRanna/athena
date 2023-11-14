import 'package:athena/extension/date_time.dart';
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

  String get title => chat.title ?? '';

  String get updatedAt {
    if (chat.updatedAt == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(chat.updatedAt!);
    return dateTime.toHumanReadableString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.inversePrimary;
    final onPrimary = colorScheme.onPrimary;
    final textTheme = theme.textTheme;
    final titleMedium = textTheme.titleMedium;
    final titleSmall = textTheme.titleSmall;

    return GestureDetector(
      onTap: onSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? primary : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.chat_bubble, size: 20, color: onPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleMedium?.copyWith(color: onPrimary),
                ),
              ),
              if (active)
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete, size: 20, color: onPrimary),
                ),
              if (!active)
                Text(
                  updatedAt,
                  style: titleSmall?.copyWith(
                    color: onPrimary.withOpacity(0.5),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
