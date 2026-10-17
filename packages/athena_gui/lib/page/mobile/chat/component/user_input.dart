import 'package:athena_gui/page/mobile/chat/component/send_button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UserInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  final void Function()? onPickImages;
  final bool isStreaming;
  final bool readOnly;
  const UserInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onTerminated,
    this.onPickImages,
    required this.isStreaming,
    this.readOnly = false,
  });

  @override
  State<UserInput> createState() => _UserInputState();
}

class _UserInputState extends State<UserInput> {
  final _scrollController = ScrollController();
  late final _focusNode = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final hintTextStyle = AthenaTextStyle.body.copyWith(color: colors.textWeak);
    final inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    final textStyle = AthenaTextStyle.body.copyWith(color: colors.textInput);
    final textField = TextField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      focusNode: _focusNode,
      scrollController: _scrollController,
      cursorColor: colors.textInput,
      decoration: inputDecoration,
      maxLines: 4,
      minLines: 1,
      onTapOutside: (_) => handleTapOutside(context),
      onChanged: (_) => _scrollToCaret(),
      style: textStyle,
      textInputAction: TextInputAction.newline,
    );
    final sendButton = SendButton(
      onSubmitted: widget.readOnly ? null : widget.onSubmitted,
      onTerminated: widget.readOnly ? null : widget.onTerminated,
      isStreaming: widget.isStreaming,
    );
    final attachButton = Tooltip(
      message: 'Add images',
      child: AthenaGhostIconButton(
        icon: LucideIcons.paperclip,
        box: AthenaIconButtonSize.touchTarget,
        iconSize: AthenaIcon.regularSize,
        onTap: widget.readOnly ? null : widget.onPickImages,
      ),
    );
    // 与桌面端共用圆角、柔阴影和青瓷聚焦边框，输入在上、操作在下。
    return AnimatedContainer(
      key: const Key('mobile-composer-shell'),
      duration: AthenaMotion.hover,
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        border: Border.all(
          color: _focusNode.hasFocus ? colors.accent : colors.neutralBorder,
        ),
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
          Row(children: [attachButton, const Spacer(), sendButton]),
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
