import 'package:athena_gui/page/mobile/chat/component/send_button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
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
      color: colors.textWeak,
      fontSize: AthenaFontSize.body,
    );
    final inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    final textStyle = TextStyle(
      color: colors.textInput,
      fontSize: AthenaFontSize.body,
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
    // 与桌面端同一形态：一整块圆角容器 + 柔阴影，输入在上、操作在下。
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AthenaRadius.composer),
        boxShadow: AthenaShadow.raised(colors.shadow),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          textField,
          const SizedBox(height: 8),
          Row(children: [const Spacer(), sendButton]),
        ],
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
