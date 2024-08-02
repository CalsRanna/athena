import 'package:athena/widget/copy_button.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.message,
    this.showToolbar = true,
    this.onDeleted,
    this.onEdited,
    this.onRegenerated,
  });

  final Message message;
  final bool showToolbar;
  final void Function()? onDeleted;
  final void Function()? onEdited;
  final void Function()? onRegenerated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shadow = colorScheme.shadow;
    final background = colorScheme.surfaceContainer;
    final error = colorScheme.error;
    final onSurface = colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.role == 'assistant')
          MarkdownWidget(
            config: MarkdownConfig(configs: [
              PreConfig(
                wrapper: (child, code, language) {
                  return Stack(children: [child, CopyButton(code: code)]);
                },
              ),
            ]),
            data: message.content,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
          ),
        if (message.role == 'user')
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: message.role == 'user' ? background : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SelectableText(message.content),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(Icons.copy, size: 12, color: onSurface.withOpacity(0.2)),
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 12, color: onSurface.withOpacity(0.2)),
              const SizedBox(width: 4),
              Icon(Icons.refresh, size: 12, color: onSurface.withOpacity(0.2)),
              const SizedBox(width: 4),
              Icon(Icons.auto_awesome_outlined,
                  size: 12, color: onSurface.withOpacity(0.2)),
            ],
          ),
        ),
      ],
    );
  }

  void copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryContainer = colorScheme.primaryContainer;
    final onPrimaryContainer = colorScheme.onPrimaryContainer;
    await Clipboard.setData(ClipboardData(text: message.content ?? ''));
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: primaryContainer,
        behavior: SnackBarBehavior.floating,
        content: Text('已复制', style: TextStyle(color: onPrimaryContainer)),
        width: 75,
      ),
    );
  }
}
