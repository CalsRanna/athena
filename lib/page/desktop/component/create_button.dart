import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/main.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

class CreateButton extends StatelessWidget {
  const CreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;
    final textTheme = theme.textTheme;
    final titleSmall = textTheme.titleSmall;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => handleTap(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: onPrimary.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20, color: onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      '新建对话',
                      style: titleSmall?.copyWith(color: onPrimary),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void handleTap(BuildContext context) async {
    final ref = context.ref;
    final chat = Chat();
    chat.title = '新建对话';
    chat.model = 'gpt-3.5-turbo-16k';
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    final chats = ref.read(chatsCreator);
    chats.add(chat);
    ref.set(chatsCreator, [...chats]);
    ref.set(currentChatCreator, chats.length - 1);
    final node = ref.read(focusNodeCreator);
    node.requestFocus();
    final controller = ref.read(textEditingControllerCreator);
    controller.clear();
  }
}
