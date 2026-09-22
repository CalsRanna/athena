import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 标准输入框：小圆角（[AthenaRadius.control]）+ 1px 实线边框 + 平涂底色。
///
/// 聚焦只让边框加深到 [AthenaColors.borderStrong]，不做焦点环、不做光晕。
class AthenaInput extends StatefulWidget {
  final bool autoFocus;
  final TextEditingController controller;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final void Function()? onBlur;
  final void Function(String)? onSubmitted;
  final String? placeholder;
  final double? radius;
  final Widget? suffix;
  const AthenaInput({
    super.key,
    this.autoFocus = false,
    required this.controller,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.onSubmitted,
    this.onBlur,
    this.placeholder,
    this.radius,
    this.suffix,
  });

  @override
  State<AthenaInput> createState() => _AthenaInputState();
}

class _AthenaInputState extends State<AthenaInput> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
    if (widget.autoFocus) {
      focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!focusNode.hasFocus) {
      widget.onBlur?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final focused = focusNode.hasFocus;
    var boxDecoration = BoxDecoration(
      color: colors.inputBackground,
      border: Border.all(color: focused ? colors.borderStrong : colors.border),
      borderRadius: BorderRadius.circular(
        widget.radius ?? AthenaRadius.control,
      ),
    );
    var hintTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: widget.placeholder,
      hintStyle: hintTextStyle,
    );
    final inputTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textInput,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 15,
      cursorColor: colors.textInput,
      cursorWidth: 1.5,
      decoration: inputDecoration,
      enabled: widget.enabled,
      focusNode: focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      obscureText: widget.obscureText,
      onSubmitted: widget.onSubmitted,
      onTapOutside: handleTapOutside,
      style: inputTextStyle,
    );
    var child = widget.suffix != null
        ? Row(
            children: [
              Expanded(child: textField),
              const SizedBox(width: 8),
              widget.suffix!,
            ],
          )
        : textField;
    return AnimatedContainer(
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }

  void handleTapOutside(PointerDownEvent event) {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}
