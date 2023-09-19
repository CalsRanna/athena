import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/provider/chat_provider.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Input extends StatefulWidget {
  const Input({super.key});

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  bool shift = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outline = colorScheme.outline;
    final primary = colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: outline.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.fromLTRB(32, 8, 32, 0),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: handleKey,
              child: Watcher((context, ref, child) {
                final controller = ref.watch(textEditingControllerCreator);
                final node = ref.watch(focusNodeCreator);
                return TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Ask me anything',
                  ),
                  focusNode: node,
                  maxLines: 3,
                  minLines: 1,
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          Watcher((context, ref, child) {
            final streaming = ref.watch(streamingCreator);
            if (streaming) {
              return SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: outline.withOpacity(0.25),
                ),
              );
            } else {
              return GestureDetector(
                onTap: handleTap,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.send,
                    color: primary,
                    size: 20,
                  ),
                ),
              );
            }
          })
        ],
      ),
    );
  }

  void handleKey(RawKeyEvent event) {
    final isShiftPressed = event.isShiftPressed;
    final isEnterPressed = event.isKeyPressed(LogicalKeyboardKey.enter);
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
      if (!isShiftPressed && isEnterPressed) {
        ChatProvider.of(context).submit();
      }
    }
  }

  void handleTap() {
    ChatProvider.of(context).submit();
  }
}
