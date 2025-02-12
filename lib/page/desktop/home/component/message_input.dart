import 'package:athena/page/desktop/home/component/model_select_dialog.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(Model)? onModelChanged;
  final void Function()? onSubmitted;
  const DesktopMessageInput({
    super.key,
    required this.controller,
    this.onModelChanged,
    this.onSubmitted,
  });

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
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(children: children),
    );
  }

  Widget _buildInput() {
    var input = _Input(controller: controller, onSubmitted: onSubmitted);
    var children = [
      Expanded(child: input),
      const SizedBox(width: 8),
      _SendButton(onTap: onSubmitted)
    ];
    return Row(children: children);
  }

  Widget _buildToolbar() {
    var children = [
      Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
      _ModelSelector(onSelected: onModelChanged),
      Icon(HugeIcons.strokeRoundedTemperature),
      Icon(HugeIcons.strokeRoundedImage01),
    ];
    return IconTheme.merge(
      data: IconThemeData(color: Color(0xFF616161)),
      child: Row(spacing: 12, children: children),
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
    var boxDecoration = BoxDecoration(
      border: Border.all(color: Color(0xFF757575)),
      borderRadius: BorderRadius.circular(24),
      color: Color(0xFFADADAD).withValues(alpha: 0.6),
    );
    var hintTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Ask me anything',
      hintStyle: hintTextStyle,
    );
    const inputTextStyle = TextStyle(
      color: Color(0xFFF5F5F5),
      fontSize: 14,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 16,
      cursorColor: Color(0xFFF5F5F5),
      decoration: inputDecoration,
      style: inputTextStyle,
      maxLines: 4,
      minLines: 1,
    );
    var keyboardListener = KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: handleKeyEvent,
      child: textField,
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: keyboardListener,
    );
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_isModifierKey(event)) shift = true;
      if (_isEnterKey(event) && !shift) widget.onSubmitted?.call();
    } else if (event is KeyUpEvent) {
      if (_isModifierKey(event)) shift = false;
    }
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
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedAiBrain01,
      color: Color(0xFF616161),
      size: 24,
    );
    var compositedTransformTarget = CompositedTransformTarget(
      link: link,
      child: hugeIcon,
    );
    return GestureDetector(
      onTap: handleTap,
      child: compositedTransformTarget,
    );
  }

  void changeModel(Model model) {
    entry?.remove();
    widget.onSelected?.call(model);
  }

  void handleTap() {
    entry = OverlayEntry(builder: _buildOverlayEntry);
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
  }

  Widget _buildOverlayEntry(BuildContext context) {
    var compositedTransformFollower = CompositedTransformFollower(
      followerAnchor: Alignment.bottomLeft,
      link: link,
      offset: const Offset(0, -12),
      targetAnchor: Alignment.topLeft,
      child: ModelSelectDialog(onTap: changeModel),
    );
    var unconstrainedBox = UnconstrainedBox(child: compositedTransformFollower);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: removeEntry,
      child: SizedBox.expand(child: unconstrainedBox),
    );
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
      onTap: onTap,
      child: outerContainer,
    );
  }
}
