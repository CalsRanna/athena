/// 设置面板里的行内控件：分段控件、下拉、密集输入框、多行输入、徽标、
/// 行尾的 `⋯` 菜单键。
///
/// 关闭 / 新增用的 ghost 图标按钮是全站通用的 `AthenaGhostIconButton`
/// （`widget/button.dart`）。
///
/// 外壳与分区见 `panel.dart`，行类组件见 `row.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// 行尾控件的几档宽度（别名，便于页面按语义取用）。
abstract final class AthenaSettingsControlWidth {
  static const narrow = AthenaSettings.controlNarrowWidth;
  static const normal = AthenaSettings.controlColumnWidth;
  static const wide = AthenaSettings.controlWideWidth;
}

/// 分段控件（Claude 的 segmented control）。
///
/// 实测：轨道 `#F3F3F3` 无描边、高 32、圆角 8；选中块是**纯白填充 +
/// 1px `#E7E7E7` 描边**并**铺满轨道高**（不是内缩的小块）；
/// 选中文字 12 半粗近黑，未选中 12 常规灰 `#898781`。
class AthenaSettingsSegmented<T> extends StatelessWidget {
  final List<AthenaSegmentOption<T>> options;
  final T selected;
  final void Function(T value)? onChanged;
  const AthenaSettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var decoration = BoxDecoration(
      color: colors.neutralRule,
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var children = [
      for (final option in options) _buildSegment(context, option),
    ];
    return Container(
      height: AthenaSettings.controlHeight,
      decoration: decoration,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSegment(BuildContext context, AthenaSegmentOption<T> option) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 未选中态不能用 `Colors.transparent`：它的 RGB 是黑，AnimatedContainer
    // 切换档位时会先闪一下半透明深灰（同 menu.dart 的说明）。用目标色的 0
    // 透明度版本，填充与边框全程同色只有 alpha 在动。
    var isSelected = option.value == selected;
    var decoration = BoxDecoration(
      color: isSelected
          ? colors.neutralControlFill
          : colors.neutralControlFill.withValues(alpha: 0),
      border: Border.all(
        color: isSelected
            ? colors.neutralBorder
            : colors.neutralBorder.withValues(alpha: 0),
      ),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var textStyle = TextStyle(
      color: isSelected ? colors.textPrimary : colors.textWeak,
      fontSize: AthenaSettings.segmentFontSize,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    );
    var segment = AnimatedContainer(
      alignment: Alignment.center,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(option.label, style: textStyle, maxLines: 1),
    );
    if (onChanged == null) return segment;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged?.call(option.value),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: segment),
    );
  }
}

/// 分段控件的一个选项。
class AthenaSegmentOption<T> {
  final T value;
  final String label;
  const AthenaSegmentOption({required this.value, required this.label});
}

/// 设置里的下拉选择（Claude 的 select 控件）。
///
/// 实测：白底、1px `#E7E7E7` 描边、高 32、圆角 8、文字 14 近黑，
/// 右端一个 chevron。它只管外观，点开的是调用方给的弹层；
/// [onTap] 收到控件的全局矩形，供弹层锚定在控件下方。
class AthenaSettingsSelect extends StatefulWidget {
  final String label;

  /// 没有值时显示的占位（灰字）。
  final bool placeholder;
  final void Function(Rect anchor)? onTap;
  const AthenaSettingsSelect({
    super.key,
    required this.label,
    this.placeholder = false,
    this.onTap,
  });

  @override
  State<AthenaSettingsSelect> createState() => _AthenaSettingsSelectState();
}

class _AthenaSettingsSelectState extends State<AthenaSettingsSelect> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var decoration = BoxDecoration(
      color: colors.neutralControlFill,
      border: Border.all(
        color: hover ? colors.neutralBorderStrong : colors.neutralBorder,
      ),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: widget.placeholder ? colors.textWeak : colors.textPrimary,
        fontSize: AthenaSettings.controlFontSize,
        height: 1.3,
      ),
    );
    var chevron = Icon(
      HugeIcons.strokeRoundedArrowDown01,
      color: colors.textWeak,
      size: 14,
    );
    var content = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.controlPaddingHorizontal,
      ),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          chevron,
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: content,
      ),
    );
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    widget.onTap!(contextMenuAnchorOf(context));
  }
}

/// 设置里的单行输入（与下拉、分段同一尺度：高 32、圆角 8、14 号字）。
///
/// 实测 Claude 的设置控件是 32 高、`#E6E6E6` 描边、14 号，比全站的
/// canonical 输入（40 高、13 号）矮一档；设置行里的输入统一用它，
/// 与同一行的其他控件齐平。
///
/// 聚焦只把描边加深到 `neutralBorderStrong`，不做焦点环。
/// [obscure] 用于密钥：默认遮住，右端一个眼睛切换明文。
/// 提交语义交给调用方：[onBlur] 失焦时回调、[onSubmitted] 回车时回调。
class AthenaSettingsTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final bool obscure;
  final bool enabled;
  final bool autofocus;

  /// 等宽（URL、模型 id 这类技术值）。
  final bool mono;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onBlur;
  const AthenaSettingsTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.mono = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onBlur,
  });

  @override
  State<AthenaSettingsTextField> createState() =>
      _AthenaSettingsTextFieldState();
}

class _AthenaSettingsTextFieldState extends State<AthenaSettingsTextField> {
  final focusNode = FocusNode();
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
    if (widget.autofocus) focusNode.requestFocus();
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!focusNode.hasFocus) widget.onBlur?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var focused = focusNode.hasFocus;
    var decoration = BoxDecoration(
      color: widget.enabled ? colors.neutralControlFill : colors.neutralRule,
      border: Border.all(
        color: focused ? colors.neutralBorderStrong : colors.neutralBorder,
      ),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var base = widget.mono
        ? athenaMono(fontSize: AthenaSettings.controlFontSize)
        : const TextStyle(fontSize: AthenaSettings.controlFontSize);
    var textStyle = base.copyWith(
      color: widget.enabled ? colors.textInput : colors.textSecondary,
      height: 1.3,
    );
    var hintStyle = base.copyWith(color: colors.textWeak, height: 1.3);
    var field = TextField(
      controller: widget.controller,
      cursorColor: colors.textInput,
      cursorHeight: 15,
      cursorWidth: 1.5,
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: hintStyle,
      ),
      enabled: widget.enabled,
      focusNode: focusNode,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscure && !revealed,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTapOutside: (_) => focusNode.unfocus(),
      style: textStyle,
    );
    var children = [
      Expanded(child: field),
      if (widget.obscure) ...[
        const SizedBox(width: 4),
        AthenaGhostIconButton(
          box: 24,
          icon: revealed
              ? HugeIcons.strokeRoundedViewOff
              : HugeIcons.strokeRoundedView,
          iconSize: 14,
          onTap: () => setState(() => revealed = !revealed),
        ),
      ],
    ];
    return AnimatedContainer(
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: EdgeInsets.only(
        left: AthenaSettings.controlPaddingHorizontal,
        right: widget.obscure ? 4 : AthenaSettings.controlPaddingHorizontal,
      ),
      child: Row(children: children),
    );
  }
}

/// 设置里的多行输入（Prompt / Instructions）：同一套描边与圆角，
/// 最少 [minLines] 行、随内容增高（在可滚动的内容区里不封顶）。
class AthenaSettingsTextArea extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final int minLines;
  final int? maxLines;
  final bool enabled;
  final bool mono;
  final ValueChanged<String>? onChanged;
  const AthenaSettingsTextArea({
    super.key,
    required this.controller,
    this.placeholder,
    this.minLines = 6,
    this.maxLines,
    this.enabled = true,
    this.mono = false,
    this.onChanged,
  });

  @override
  State<AthenaSettingsTextArea> createState() => _AthenaSettingsTextAreaState();
}

class _AthenaSettingsTextAreaState extends State<AthenaSettingsTextArea> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var focused = focusNode.hasFocus;
    var decoration = BoxDecoration(
      color: widget.enabled ? colors.neutralControlFill : colors.neutralRule,
      border: Border.all(
        color: focused ? colors.neutralBorderStrong : colors.neutralBorder,
      ),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var base = widget.mono
        ? athenaMono(fontSize: AthenaSettings.controlFontSize)
        : const TextStyle(fontSize: AthenaSettings.controlFontSize);
    var textStyle = base.copyWith(
      color: widget.enabled ? colors.textInput : colors.textSecondary,
      height: 1.5,
    );
    var hintStyle = base.copyWith(color: colors.textWeak, height: 1.5);
    var field = TextField(
      controller: widget.controller,
      cursorColor: colors.textInput,
      cursorWidth: 1.5,
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: hintStyle,
      ),
      enabled: widget.enabled,
      focusNode: focusNode,
      keyboardType: TextInputType.multiline,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onChanged: widget.onChanged,
      onTapOutside: (_) => focusNode.unfocus(),
      style: textStyle,
    );
    return AnimatedContainer(
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.controlPaddingHorizontal,
        vertical: 10,
      ),
      child: field,
    );
  }
}

/// 小徽标（Claude 挂在默认模型名后的 `Default` 那种）：浅灰底、说明字号、
/// 圆角 4。用在行标签后面（`Built-in` / `Archived`）与菜单条目里。
class AthenaSettingsBadge extends StatelessWidget {
  final String text;
  const AthenaSettingsBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceButtonSecondary,
        borderRadius: BorderRadius.circular(AthenaRadius.xs),
      ),
      child: Text(
        text,
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textSecondary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 行尾的 `⋯` 菜单键：点开一个锚在按钮下方、右边与它对齐的菜单。
///
/// 右键菜单的替身——右键仍然可用，但这个键让条目的动作可被发现。
/// 菜单会碰到窗口底部时改为向上展开。
class AthenaSettingsMenuButton extends StatelessWidget {
  final List<Widget> items;
  final double menuWidth;
  const AthenaSettingsMenuButton({
    super.key,
    required this.items,
    this.menuWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => AthenaGhostIconButton(
        box: 24,
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        iconSize: 14,
        onTap: () => _open(context),
      ),
    );
  }

  void _open(BuildContext context) {
    final anchor = contextMenuAnchorOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    // 面板自带 4 内边距，条目宽 + 8 才是面板外宽
    final left = anchor.right - menuWidth - 8;
    // 估一个菜单高（每项约 32 + 内边距），够不到底就向上翻
    final estimated = items.length * 32.0 + 8;
    final upward = anchor.bottom + 4 + estimated > screenHeight - 12;
    final menu = DesktopContextMenu(
      offset: upward
          ? Offset(left, anchor.top - 4)
          : Offset(left, anchor.bottom + 4),
      upward: upward,
      width: menuWidth,
      children: items,
    );
    DesktopContextMenuManager.instance.show(context, menu);
  }
}
