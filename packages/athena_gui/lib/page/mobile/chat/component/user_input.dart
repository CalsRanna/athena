import 'package:athena_gui/page/mobile/chat/component/send_button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

class UserInput extends StatefulWidget {
  final TextEditingController controller;
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  final bool isStreaming;
  const UserInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onTerminated,
    required this.isStreaming,
  });

  @override
  State<UserInput> createState() => _UserInputState();
}

class _UserInputState extends State<UserInput> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final hintTextStyle = TextStyle(
      color: colors.border,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    final textStyle = TextStyle(
      color: colors.textInput,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textField = TextField(
      controller: widget.controller,
      scrollController: _scrollController,
      cursorColor: colors.textInput,
      decoration: inputDecoration,
      maxLines: 2,
      minLines: 2,
      onTapOutside: (_) => handleTapOutside(context),
      onChanged: (_) => _scrollToCaret(),
      style: textStyle,
      textInputAction: TextInputAction.newline,
    );
    var sendButton = SendButton(
      onSubmitted: widget.onSubmitted,
      onTerminated: widget.onTerminated,
      isStreaming: widget.isStreaming,
    );
    var shapeDecoration = ShapeDecoration(
      color: colors.inputBackground.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
    var rowChildren = [
      Expanded(child: textField),
      const SizedBox(width: 16),
      sendButton,
    ];
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }

  /// 多行输入超过可视高度时滚动到光标所在的最新一行
  /// （TextField 不会自动跟随光标，需在文本变化后手动滚动）。
  void _scrollToCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent > 0) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  void handleTapOutside(BuildContext context) {
    // FocusScope.of(context) 在焦点位于输入框自身时自身并不持焦,
    // unfocus 会直接返回;必须对实际持焦节点释放焦点。
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
