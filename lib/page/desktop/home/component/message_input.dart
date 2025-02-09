import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopMessageInput extends StatefulWidget {
  final void Function(Model)? onModelChanged;
  final void Function(String)? onSubmitted;
  const DesktopMessageInput({super.key, this.onModelChanged, this.onSubmitted});

  @override
  State<DesktopMessageInput> createState() => _DesktopMessageInputState();
}

class _DesktopMessageInputState extends State<DesktopMessageInput> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var children = [
      _buildToolbar(),
      const SizedBox(height: 12),
      _buildInput(),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(top: borderSide)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(children: children),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void sendMessage() {
    var container = ProviderScope.containerOf(context);
    final streaming = container.read(streamingNotifierProvider);
    if (streaming) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    FocusScope.of(context).unfocus();
    widget.onSubmitted?.call(text);
  }

  Widget _buildInput() {
    var input = _Input(controller: controller, onSubmitted: sendMessage);
    var children = [
      Expanded(child: input),
      const SizedBox(width: 8),
      _SendButton(onTap: sendMessage)
    ];
    return Row(children: children);
  }

  Widget _buildToolbar() {
    var children = [
      Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
      _ModelSelector(onSelected: widget.onModelChanged),
      Icon(HugeIcons.strokeRoundedTemperature),
      Icon(HugeIcons.strokeRoundedImage01),
    ];
    return IconTheme.merge(
      data: IconThemeData(color: Color(0xFF616161)),
      child: Row(spacing: 12, children: children),
    );
  }
}

class _Dialog extends ConsumerWidget {
  final void Function(Model)? onTap;
  const _Dialog({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelsNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return ACard(child: child);
  }

  Widget _buildData(List<Model> models) {
    if (models.isEmpty) return const SizedBox();
    var children = models.map((model) => _itemBuilder(model)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _itemBuilder(Model model) {
    return ATile(
      onTap: () => onTap?.call(model),
      title: model.name,
      width: 320,
    );
  }
}

class _Input extends StatefulWidget {
  final TextEditingController controller;
  final void Function()? onSubmitted;
  const _Input({required this.controller, this.onSubmitted});

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  bool shift = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFF757575)),
          borderRadius: BorderRadius.circular(24),
          color: Color(0xFFADADAD).withValues(alpha: 0.6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) => handleKeyEvent(ref, event),
          child: TextField(
            controller: widget.controller,
            cursorHeight: 16,
            cursorColor: Color(0xFFF5F5F5),
            decoration: InputDecoration.collapsed(
              hintText: 'Ask me anything',
              hintStyle: TextStyle(
                color: Color(0xFFC2C2C2),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            style: const TextStyle(
                color: Color(0xFFF5F5F5), fontSize: 14, height: 1.5),
            maxLines: 4,
            minLines: 1,
          ),
        ),
      );
    });
  }

  void handleKeyEvent(WidgetRef ref, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_isModifierKey(event)) shift = true;
      if (_isEnterKey(event) && !shift) send(ref);
    } else if (event is KeyUpEvent) {
      if (_isModifierKey(event)) shift = false;
    }
  }

  Future<void> send(WidgetRef ref) async {
    widget.onSubmitted?.call();
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

class _ModelSelector extends StatefulWidget {
  final void Function(Model)? onSelected;
  const _ModelSelector({this.onSelected});

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

  void changeModel(Model model) {
    entry?.remove();
    widget.onSelected?.call(model);
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
              child: _Dialog(onTap: changeModel),
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

class _SendButton extends ConsumerWidget {
  final void Function()? onTap;
  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.transparent,
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.centerLeft,
      colors: colors,
      end: Alignment.centerRight,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(55),
      gradient: linearGradient,
    );
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: Color(0xFFCED2E7).withValues(alpha: 0.5),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(55),
      color: Colors.white,
      boxShadow: [boxShadow],
    );
    var streaming = ref.watch(streamingNotifierProvider);
    var iconData = HugeIcons.strokeRoundedSent;
    if (streaming) iconData = HugeIcons.strokeRoundedStop;
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      child: Icon(iconData),
    );
    var outerContainer = Container(
      decoration: boxDecoration,
      height: 55,
      padding: EdgeInsets.all(1),
      width: 55,
      child: innerContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(ref),
      child: outerContainer,
    );
  }

  void handleTap(WidgetRef ref) {
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onTap?.call();
  }
}
