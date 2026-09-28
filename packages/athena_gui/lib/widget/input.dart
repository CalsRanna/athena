import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 标准输入框：小圆角（[AthenaRadius.control]）+ 1px 实线边框 + 平涂底色。
///
/// 聚焦时使用 [AthenaColors.accent] 的 1px 边框，不做焦点环、不做光晕。
///
/// [obscureText] 为真时右端自动带一枚眼睛键切换明文（与 [AthenaSettingsTextField]
/// 同一约定：遮蔽时显示 `eye`、显示明文时换成 `eyeOff`）。密钥类字段直接传
/// `obscureText: true` 即可，不要各自再搓一个 toggle 塞进 [suffix]。
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

  /// 额外的尾部控件。[obscureText] 为真时排在眼睛键左边。
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

  /// 是否已切换成明文。只在 [AthenaInput.obscureText] 为真时有意义。
  bool revealed = false;

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
      border: Border.all(color: focused ? colors.accent : colors.border),
      borderRadius: BorderRadius.circular(
        widget.radius ?? AthenaRadius.control,
      ),
    );
    var hintTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: widget.placeholder,
      hintStyle: hintTextStyle,
    );
    final inputTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textInput,
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
      obscureText: widget.obscureText && !revealed,
      onSubmitted: widget.onSubmitted,
      onTapOutside: handleTapOutside,
      style: inputTextStyle,
    );
    var children = [
      Expanded(child: textField),
      if (widget.suffix != null) ...[
        const SizedBox(width: 8),
        widget.suffix!,
      ],
      if (widget.obscureText) ...[
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => revealed = !revealed),
          child: Icon(
            revealed ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 18,
            color: colors.border,
          ),
        ),
      ],
    ];
    return AnimatedContainer(
      decoration: boxDecoration,
      duration: AthenaMotion.hover,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: children),
    );
  }

  void handleTapOutside(PointerDownEvent event) {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}
