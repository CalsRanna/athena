import 'package:athena/provider/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Input extends StatefulWidget {
  const Input({super.key});

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  final controller = TextEditingController();
  bool shift = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outline = colorScheme.outline;

    return Consumer(builder: (context, ref, child) {
      ref.watch(chatNotifierProvider);
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: outline.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(32, 8, 32, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => handleKeyEvent(ref, event),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Ask me anything',
                  ),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void handleKeyEvent(WidgetRef ref, KeyEvent event) {
    bool isShift() {
      const left = LogicalKeyboardKey.shiftLeft;
      const right = LogicalKeyboardKey.shiftRight;
      return [left, right].contains(event.logicalKey);
    }

    bool isEnter() => event.logicalKey == LogicalKeyboardKey.enter;

    if (event is KeyDownEvent) {
      if (isShift()) shift = true;
      if (shift && isEnter()) {
        send(ref);
      }
    } else if (event is KeyUpEvent) {
      if (isShift()) shift = false;
    }
  }

  void send(WidgetRef ref) {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    FocusScope.of(context).unfocus();
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.send(text);
  }
}
