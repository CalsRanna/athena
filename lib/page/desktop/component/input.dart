import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Input extends StatelessWidget {
  const Input({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _ModelSelector(),
        SizedBox(width: 8),
        Expanded(child: _Input()),
      ],
    );
  }
}

class _Input extends StatefulWidget {
  const _Input({super.key});

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
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
          border: Border.all(color: outline.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => handleKeyEvent(ref, event),
                child: TextField(
                  controller: controller,
                  cursorHeight: 16,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Ask me anything',
                    hintStyle: TextStyle(
                      color: outline.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
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
        shift = false;
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

class _ModelSelector extends StatefulWidget {
  const _ModelSelector({super.key});

  @override
  State<_ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<_ModelSelector> {
  OverlayEntry? entry;
  final link = LayerLink();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: handleTap,
      child: CompositedTransformTarget(
        link: link,
        child: const Icon(Icons.auto_awesome_outlined),
      ),
    );
  }

  void handleTap() {
    entry = OverlayEntry(builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: removeEntry,
        child: SizedBox.expand(
          child: UnconstrainedBox(
            child: CompositedTransformFollower(
              followerAnchor: Alignment.bottomLeft,
              link: link,
              offset: const Offset(0, -12),
              targetAnchor: Alignment.topLeft,
              child: _Dialog(onTap: removeEntry),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
  }
}

class _Dialog extends StatelessWidget {
  final void Function()? onTap;
  const _Dialog({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.primary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: 200,
      child: Consumer(builder: (context, ref, child) {
        final state = ref.watch(modelsNotifierProvider);
        return switch (state) {
          AsyncData(:final value) => _List(onTap: onTap, models: value),
          _ => const SizedBox(),
        };
      }),
    );
  }
}

class _List extends StatelessWidget {
  final void Function()? onTap;
  final List<Model> models;
  const _List({super.key, this.onTap, required this.models});

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: getChildren(context),
    );
  }

  List<Widget> getChildren(BuildContext context) {
    return models.map((model) => _Tile(model, onTap: onTap)).toList();
  }
}

class _Tile extends StatelessWidget {
  final void Function()? onTap;
  final Model model;
  const _Tile(this.model, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
        onTap: () => handleTap(ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            model.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              decoration: TextDecoration.none,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    });
  }

  void handleTap(WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.updateModel(model.value);
    onTap?.call();
  }
}
