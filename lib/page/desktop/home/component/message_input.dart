import 'package:athena/page/desktop/home/component/information_indicator.dart';
import 'package:athena/page/desktop/home/component/mcp_tool_indicator.dart';
import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/page/desktop/home/component/search_decision_toggle.dart';
import 'package:athena/page/desktop/home/component/sentinel_selector.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopMessageInput extends StatelessWidget {
  final Chat chat;
  final TextEditingController controller;
  final void Function()? onChatConfigurationButtonTapped;
  final void Function(Model)? onModelChanged;
  final void Function(bool)? onSearchDecisionChanged;
  final void Function(Sentinel)? onSentinelChanged;
  final void Function()? onSubmitted;
  const DesktopMessageInput({
    super.key,
    required this.chat,
    required this.controller,
    this.onChatConfigurationButtonTapped,
    this.onModelChanged,
    this.onSearchDecisionChanged,
    this.onSentinelChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    var toolbarChildren = [
      DesktopSentinelSelector(onSelected: onSentinelChanged),
      DesktopModelSelector(onSelected: onModelChanged),
      DesktopChatSearchDecisionButton(
        chat: chat,
        onTap: onSearchDecisionChanged,
      ),
      _ChatConfigurationButton(
        chat: chat,
        onTap: onChatConfigurationButtonTapped,
      ),
      // Icon(HugeIcons.strokeRoundedImage01),
      DesktopInformationIndicator(),
      const Spacer(),
      DesktopMcpToolIndicator(),
    ];
    var toolbar = IconTheme.merge(
      data: IconThemeData(color: ColorUtil.FF616161, size: 24),
      child: Row(spacing: 12, children: toolbarChildren),
    );
    var input = _Input(controller: controller, onSubmitted: onSubmitted);
    var inputChildren = [
      Expanded(child: input),
      const SizedBox(width: 8),
      _SendButton(onTap: onSubmitted)
    ];
    var inputRow = Row(children: inputChildren);
    var borderSide =
        BorderSide(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2));
    var children = [toolbar, const SizedBox(height: 12), inputRow];
    return Container(
      decoration: BoxDecoration(border: Border(top: borderSide)),
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(children: children),
    );
  }
}

class _ChatConfigurationButton extends StatelessWidget {
  final Chat chat;
  final void Function()? onTap;
  const _ChatConfigurationButton({required this.chat, this.onTap});

  @override
  Widget build(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedSlidersHorizontal,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
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
      border: Border.all(color: ColorUtil.FF757575),
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
    );
    var hintTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Ask me anything',
      hintStyle: hintTextStyle,
    );
    const inputTextStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 16,
      cursorColor: ColorUtil.FFF5F5F5,
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
    } else if (event is KeyUpEvent) {
      if (_isModifierKey(event)) shift = false;
      if (_isEnterKey(event) && !shift) widget.onSubmitted?.call();
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

class _SendButton extends ConsumerWidget {
  final void Function()? onTap;
  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
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
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(55),
      color: ColorUtil.FFFFFFFF,
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
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: outerContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: mouseRegion,
    );
  }
}
