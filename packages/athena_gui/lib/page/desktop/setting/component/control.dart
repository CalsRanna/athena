/// 设置面板里的行内控件：下拉、密集输入框、多行输入、徽标、
/// 行尾的 `⋯` 菜单键。
///
/// 关闭 / 新增用的 ghost 图标按钮是全站通用的 `AthenaGhostIconButton`
/// （`widget/button.dart`）。
///
/// 外壳与分区见 `panel.dart`，行类组件见 `row.dart`。
library;

import 'dart:math' as math;

import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 小徽标（行标题后的 `Built-in` / `Archived` 那种）：浅灰底、说明字号、
/// 圆角 4。用在行标签后面与菜单条目里。
class AthenaSettingsBadge extends StatelessWidget {
  final String text;
  const AthenaSettingsBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
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

/// 行尾控件的几档宽度（别名，便于页面按语义取用）。
abstract final class AthenaSettingsControlWidth {
  static const narrow = AthenaSettings.controlNarrowWidth;
  static const normal = AthenaSettings.controlColumnWidth;
  static const wide = AthenaSettings.controlWideWidth;
}

/// 设置里的下拉选择：外壳同 [AthenaSettingsSelect]，点开一个锚在它下方、
/// 与选择菜单同宽的菜单，当前值在行尾打钩（与设置里的其他选择器共用同一套菜单）。
///
/// 触发控件按当前值收紧；菜单沿用 [AthenaSettingsSelect.menuWidth]，
/// 保证较长的选项也放得下。
/// [selected] 不在 [options] 里时不显示值（存储里可能残留已去掉的档位）。
class AthenaSettingsDropdown<T> extends StatelessWidget {
  final List<AthenaSettingsDropdownOption<T>> options;
  final T selected;
  final void Function(T value)? onChanged;

  const AthenaSettingsDropdown({
    super.key,
    required this.options,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = _labelOf(selected);
    return AthenaSettingsSelect(
      label: label ?? '',
      placeholder: label == null,
      onTap: onChanged == null ? null : (anchor) => _open(context, anchor),
    );
  }

  String? _labelOf(T value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return null;
  }

  void _open(BuildContext context, Rect anchor) {
    // 触发控件按当前值收紧，菜单沿用统一的选择菜单宽度；触控件更宽时与它同宽。
    final width = math.max(anchor.width - 8, AthenaSettingsSelect.menuWidth);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final below = screenHeight - anchor.bottom - 16;
    final upward = below < 200 && anchor.top > below;
    final maxHeight = (upward ? anchor.top - 16 : below).clamp(120.0, 300.0);
    // 菜单右边与触发控件右边对齐（同 AthenaSettingsMenuButton 的惯例）；
    // 面板自带 4 内边距，条目宽 + 8 才是面板外宽。
    final left = anchor.right - width - 8;
    DesktopContextMenuManager.instance.show(
      context,
      DesktopContextMenu(
        offset: upward
            ? Offset(left, anchor.top - 4)
            : Offset(left, anchor.bottom + 4),
        upward: upward,
        width: width,
        children: [
          DesktopContextMenuList(
            maxHeight: maxHeight,
            children: [
              for (final option in options)
                DesktopContextMenuTile(
                  text: option.label,
                  selected: option.value == selected,
                  onTap: () {
                    if (option.value != selected) onChanged?.call(option.value);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 下拉选择的一项。
class AthenaSettingsDropdownOption<T> {
  final T value;
  final String label;
  const AthenaSettingsDropdownOption({
    required this.value,
    required this.label,
  });
}

/// 行尾的 `⋯` 菜单键：点开一个锚在按钮下方、右边与它对齐的菜单。
///
/// 右键菜单的替身——右键仍然可用，但这个键让条目的动作可被发现。
/// 菜单会碰到窗口底部时改为向上展开。
class AthenaSettingsMenuButton extends StatelessWidget {
  final List<Widget> items;
  final double menuWidth;
  final IconData icon;
  const AthenaSettingsMenuButton({
    super.key,
    required this.items,
    this.menuWidth = 160,
    this.icon = AthenaIcons.more,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) =>
          AthenaGhostIconButton(icon: icon, onTap: () => _open(context)),
    );
  }

  void _open(BuildContext context) {
    final anchor = DesktopContextMenu.contextMenuAnchorOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    // 面板自带 4 内边距，条目宽 + 8 才是面板外宽
    final left = anchor.right - menuWidth - 8;
    // 估一个菜单高（22 行盒 + 上下各 8），够不到底就向上翻
    final estimated = items.length * 38.0 + 8;
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

/// 设置里的下拉选择。
///
/// 高 36、圆角 8、文字 14 / 22，右端一个 chevron。**没有描边**：默认是
/// 语义表面色，hover 换成 neutralRule；宽度收紧到当前显示的文字
/// （父级约束更窄时文字省略）。
/// 它只管外观，点开的是调用方给的弹层；
/// [onTap] 收到控件的全局矩形，供弹层锚定在控件下方。
class AthenaSettingsSelect extends StatefulWidget {
  /// 弹出菜单的宽度：与 composer 的模型 / 推理强度等选择菜单一致（264）。
  /// 触发控件比它更宽时菜单与控件同宽。
  static const menuWidth = 264.0;

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

/// 设置里的多行输入（Prompt / Instructions）：同一套描边与圆角，
/// 最少 [minLines] 行、随内容增高（在可滚动的内容区里不封顶）。
class AthenaSettingsTextArea extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final int minLines;
  final int? maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  const AthenaSettingsTextArea({
    super.key,
    required this.controller,
    this.placeholder,
    this.minLines = 6,
    this.maxLines,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<AthenaSettingsTextArea> createState() => _AthenaSettingsTextAreaState();
}

/// 设置里的单行输入（与下拉同一尺度：高 36、圆角 8、14 / 22 文字）。
///
/// 比全站的标准输入（[AthenaInput]，40 高）矮一档：设置行里的输入统一用它，
/// 与同一行的其他控件齐平。
///
/// 聚焦时使用 `accent` 的 1px 边框，不做焦点环。
/// [obscure] 用于密钥：默认遮住，右端一个眼睛切换明文。
/// 提交语义交给调用方：[onBlur] 失焦时回调、[onSubmitted] 回车时回调。
class AthenaSettingsTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final bool obscure;
  final bool enabled;
  final bool autofocus;

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

class _AthenaSettingsSelectState extends State<AthenaSettingsSelect> {
  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AthenaTextStyle.row.copyWith(
        color: widget.placeholder ? colors.textWeak : colors.textPrimary,
      ),
    );
    final chevron = Icon(
      AthenaIcons.dropdown,
      color: colors.textWeak,
      size: AthenaIcon.inlineSize,
    );
    return IntrinsicWidth(
      child: AthenaHover(
        onTap: _handleTap,
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => AnimatedContainer(
          alignment: Alignment.centerLeft,
          // 无描边：静止态留语义表面色，hover 换 neutralRule 作反馈。
          decoration: BoxDecoration(
            color: hover ? colors.neutralRule : colors.neutralControlFill,
            borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
          ),
          duration: AthenaMotion.hover,
          height: AthenaSettings.controlHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AthenaSettings.controlPaddingHorizontal,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: 8),
              chevron,
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    widget.onTap!(DesktopContextMenu.contextMenuAnchorOf(context));
  }
}

class _AthenaSettingsTextAreaState extends State<AthenaSettingsTextArea> {
  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final focused = focusNode.hasFocus;
    final decoration = BoxDecoration(
      color: widget.enabled ? colors.neutralControlFill : colors.neutralRule,
      border: Border.all(color: focused ? colors.accent : colors.neutralBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    final textStyle = AthenaTextStyle.row.copyWith(
      color: widget.enabled ? colors.textInput : colors.textSecondary,
    );
    final hintStyle = AthenaTextStyle.row.copyWith(color: colors.textWeak);
    final field = TextField(
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
      duration: AthenaMotion.hover,
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.controlPaddingHorizontal,
        vertical: 10,
      ),
      child: field,
    );
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }
}

class _AthenaSettingsTextFieldState extends State<AthenaSettingsTextField> {
  final focusNode = FocusNode();
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final focused = focusNode.hasFocus;
    final decoration = BoxDecoration(
      color: widget.enabled ? colors.neutralControlFill : colors.neutralRule,
      border: Border.all(color: focused ? colors.accent : colors.neutralBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    final textStyle = AthenaTextStyle.row.copyWith(
      color: widget.enabled ? colors.textInput : colors.textSecondary,
    );
    final hintStyle = AthenaTextStyle.row.copyWith(color: colors.textWeak);
    final field = TextField(
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
    final children = [
      Expanded(child: field),
      if (widget.obscure) ...[
        const SizedBox(width: 4),
        AthenaGhostIconButton(
          icon: revealed ? LucideIcons.eyeOff : LucideIcons.eye,
          onTap: () => setState(() => revealed = !revealed),
        ),
      ],
    ];
    return AnimatedContainer(
      decoration: decoration,
      duration: AthenaMotion.hover,
      height: AthenaSettings.controlHeight,
      padding: EdgeInsets.only(
        left: AthenaSettings.controlPaddingHorizontal,
        right: widget.obscure ? 4 : AthenaSettings.controlPaddingHorizontal,
      ),
      child: Row(children: children),
    );
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
    if (widget.autofocus) focusNode.requestFocus();
  }

  void _handleFocusChange() {
    if (!focusNode.hasFocus) widget.onBlur?.call();
    if (mounted) setState(() {});
  }
}
