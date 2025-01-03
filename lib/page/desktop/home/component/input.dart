import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class Input extends StatelessWidget {
  const Input({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              _ModelSelector(),
              const SizedBox(width: 8),
              Icon(HugeIcons.strokeRoundedImage01, color: Color(0xFF616161)),
              const SizedBox(width: 8),
              Icon(HugeIcons.strokeRoundedTemperature,
                  color: Color(0xFF616161)),
              const SizedBox(width: 8),
              Icon(HugeIcons.strokeRoundedGift, color: Color(0xFF616161)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: _Input()),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(55),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    colors: [
                      Color(0xFFEAEAEA).withValues(alpha: 0.17),
                      Colors.transparent,
                    ],
                    end: Alignment.centerRight,
                  ),
                ),
                height: 55,
                padding: EdgeInsets.all(1),
                width: 55,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(55),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 16,
                        color: Color(0xFFCED2E7).withValues(alpha: 0.5),
                      )
                    ],
                  ),
                  child: Icon(HugeIcons.strokeRoundedSent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dialog extends StatelessWidget {
  final void Function()? onTap;
  const _Dialog({this.onTap});

  @override
  Widget build(BuildContext context) {
    return ACard(
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

class _Input extends StatefulWidget {
  const _Input();

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  final controller = TextEditingController();
  bool shift = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      ref.watch(chatNotifierProvider(0));
      return Container(
        decoration: ShapeDecoration(
          color: Color(0xFFADADAD).withValues(alpha: 0.6),
          shape: StadiumBorder(side: BorderSide(color: Color(0xFF757575))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) => handleKeyEvent(ref, event),
          child: TextField(
            controller: controller,
            cursorHeight: 16,
            cursorColor: Color(0xFFF5F5F5),
            decoration: InputDecoration.collapsed(
              hintText: 'Ask me anything',
              hintStyle: TextStyle(
                color: Color(0xFFC2C2C2),
                fontSize: 14,
                height: 1.7,
              ),
            ),
            style: const TextStyle(
                color: Color(0xFFF5F5F5), fontSize: 14, height: 1.7),
            maxLines: 4,
            minLines: 1,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleKeyEvent(WidgetRef ref, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_isModifierKey(event)) shift = true;
      if (_isEnterKey(event) && !shift) send(ref);
    } else if (event is KeyUpEvent) {
      if (_isModifierKey(event)) shift = false;
    }
  }

  void send(WidgetRef ref) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    controller.clear();
    FocusScope.of(context).unfocus();
    final notifier = ref.read(chatNotifierProvider(0).notifier);
    notifier.send(text);
  }

  bool _isEnterKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter;
  }

  bool _isModifierKey(KeyEvent event) {
    const modifierKeys = [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    ];
    return modifierKeys.contains(event.logicalKey);
  }
}

class _List extends StatelessWidget {
  final void Function()? onTap;
  final List<Model> models;
  const _List({this.onTap, required this.models});

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

class _ModelSelector extends StatefulWidget {
  const _ModelSelector();

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
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAiBrain01,
          color: Color(0xFF616161),
          size: 24,
        ),
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
  }
}

class _Tile extends StatelessWidget {
  final void Function()? onTap;
  final Model model;
  const _Tile(this.model, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      return ATile(onTap: () => handleTap(ref), title: model.name, width: 160);
    });
  }

  void handleTap(WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider(0).notifier);
    notifier.updateModel(model.value);
    onTap?.call();
  }
}
