import 'package:athena/page/desktop/home/component/configuration_button.dart';
import 'package:athena/page/desktop/home/component/image_selector.dart';
import 'package:athena/page/desktop/home/component/token_indicator.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(int)? onRetentionChange;
  final void Function(List<String>)? onImageSelected;
  final void Function()? onSubmitted;
  final void Function(double)? onTemperatureChange;
  final void Function()? onTerminated;
  const DesktopMessageInput({
    super.key,
    required this.controller,
    this.onRetentionChange,
    this.onImageSelected,
    this.onSubmitted,
    this.onTemperatureChange,
    this.onTerminated,
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var chat = chatViewModel.currentChat.value;
      var toolbarChildren = [
        DesktopConfigurationButton(
          chat: chat,
          currentRetention: chatViewModel.currentRetention.value,
          currentTemperature: chatViewModel.currentTemperature.value,
          onRetentionChange: onRetentionChange,
          onTemperatureChange: onTemperatureChange,
        ),
        DesktopImageSelector(onSelected: onImageSelected),
        const Spacer(),
        const DesktopTokenIndicator(),
      ];
      var toolbar = Row(spacing: 12, children: toolbarChildren);
      var input = _Input(controller: controller, onSubmitted: onSubmitted);
      var inputChildren = [
        Expanded(child: input),
        const SizedBox(width: 8),
        _SendButton(onSubmitted: onSubmitted, onTerminated: onTerminated),
      ];
      var inputRow = Row(children: inputChildren);
      var borderSide = BorderSide(
        color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      );
      var children = [toolbar, const SizedBox(height: 12), inputRow];
      return Container(
        decoration: BoxDecoration(border: Border(top: borderSide)),
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(children: children),
      );
    });
  }
}

class _Input extends StatefulWidget {
  final TextEditingController controller;
  final void Function()? onSubmitted;
  const _Input({required this.controller, this.onSubmitted});

  @override
  State<_Input> createState() => _InputState();
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
}

class _InputState extends State<_Input> {
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
    var shortcuts = Shortcuts(
      shortcuts: const {
        _SendActivator(): _SendIntent(),
        _SendNumpadActivator(): _SendIntent(),
        _NewlineActivator(): _NewlineIntent(),
      },
      child: Actions(
        actions: {
          _SendIntent: CallbackAction<_SendIntent>(
            onInvoke: (_) {
              widget.onSubmitted?.call();
              return null;
            },
          ),
          _NewlineIntent: CallbackAction<_NewlineIntent>(
            onInvoke: (_) => _insertNewline(),
          ),
        },
        child: textField,
      ),
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: shortcuts,
    );
  }

  void _insertNewline() {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final newText =
        '${text.substring(0, selection.start)}\n${text.substring(selection.end)}';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
  }
}

class _SendActivator extends SingleActivator {
  const _SendActivator()
      : super(
          LogicalKeyboardKey.enter,
          shift: false,
          control: false,
          alt: false,
          meta: false,
        );
}

class _SendNumpadActivator extends SingleActivator {
  const _SendNumpadActivator()
      : super(
          LogicalKeyboardKey.numpadEnter,
          shift: false,
          control: false,
          alt: false,
          meta: false,
        );
}

class _NewlineActivator extends SingleActivator {
  const _NewlineActivator()
      : super(LogicalKeyboardKey.enter, shift: true);
}

class _SendButton extends StatelessWidget {
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  const _SendButton({this.onSubmitted, this.onTerminated});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
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

    return Watch((context) {
      var streaming = chatViewModel.isStreaming.value;
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
        onTap: () => handleTap(streaming),
        child: mouseRegion,
      );
    });
  }

  void handleTap(bool streaming) {
    if (!streaming) {
      onSubmitted?.call();
      return;
    }
    onTerminated?.call();
  }
}
