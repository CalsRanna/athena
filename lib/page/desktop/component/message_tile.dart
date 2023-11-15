import 'package:athena/widget/copy_button.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (message.content == null) {
      return const SizedBox();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shadow = colorScheme.shadow;
    final background = colorScheme.background;
    final error = colorScheme.error;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(4, 4),
          )
        ],
        color: background,
      ),
      margin: const EdgeInsets.only(bottom: 8, top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MarkdownWidget(
            config: MarkdownConfig(configs: [
              PreConfig(
                wrapper: (child, code) {
                  return Stack(children: [child, CopyButton(code: code)]);
                },
              ),
            ]),
            data: message.content ?? '',
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                if (message.role == 'user' && showToolbar)
                  TextButton(onPressed: onEdited, child: const Text('编辑')),
                if (message.role != 'user' && showToolbar)
                  ElevatedButton(
                      onPressed: onRegenerated, child: const Text('重新生成')),
                const SizedBox(width: 4),
                if (message.role == 'user' && showToolbar)
                  TextButton(
                    onPressed: onDeleted,
                    child: Text('删除', style: TextStyle(color: error)),
                  ),
                if (message.role != 'user' && showToolbar)
                  TextButton(
                      onPressed: () => copy(context), child: const Text('复制')),
              ],
            ),
          ),
        ],
      ),
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
