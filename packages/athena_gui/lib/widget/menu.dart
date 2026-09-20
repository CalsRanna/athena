import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 桌面左侧栏/列表行。Codex 风格：整行 hover 底色 + 选中行提亮，
/// 没有渐变边框、没有胶囊。
class DesktopMenuTile extends StatefulWidget {
  final bool active;
  final String label;
  final Widget? leading;
  final void Function(TapUpDetails)? onSecondaryTap;
  final void Function()? onTap;
  final Widget? trailing;

  /// 仅在 hover 时出现的尾部（Claude 的会话行 hover 才显示 `⋮`）。
  final Widget? hoverTrailing;

  /// 需要感知 hover 的 leading（Claude 的状态点在 hover 时会加深）。
  final Widget Function(bool hover)? leadingBuilder;

  const DesktopMenuTile({
    super.key,
    required this.active,
    required this.label,
    this.leading,
    this.leadingBuilder,
    this.onSecondaryTap,
    this.onTap,
    this.trailing,
    this.hoverTrailing,
  });

  @override
  State<DesktopMenuTile> createState() => _DesktopMenuTileState();
}

class _DesktopMenuTileState extends State<DesktopMenuTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    const duration = Duration(milliseconds: 120);
    // Claude 实测：**hover 只改底色，文字不动**。选中行才提亮文字。
    // 旧版在 hover 时把标签从次级灰跳到近黑，观感是"文字闪一下"，是错的。
    var contentColor = widget.active
        ? colors.textPrimary
        : colors.textRowLabel;
    // 列表行（侧栏会话、设置页各行）取 UI 正文档 14，不是 label 档 12。
    // Claude 实测：侧栏会话行与消息正文（15）只差 1px；用 12 会让侧栏
    // 明显比工作区小一号。
    var textStyle = TextStyle(
      color: contentColor,
      fontSize: AthenaFontSize.body,
      fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
      height: AthenaFontSize.bodyHeight,
    );
    var text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    // 不能从 `Colors.transparent` 做插值：它的 RGB 是黑，AnimatedContainer
    // 从中途经过时会渲染成"半透明深灰"，表现为 hover 先闪一下深色再变浅。
    // 用目标色的 0 透明度版本，RGB 全程一致，只有 alpha 在动。
    var resting = colors.surfaceHover.withValues(alpha: 0);
    var background = widget.active
        ? colors.surfaceSelected
        : hover
        ? colors.surfaceHover
        : resting;
    var leading = widget.leadingBuilder != null
        ? widget.leadingBuilder!(hover)
        : widget.leading;
    var iconTheme = IconTheme(
      data: IconThemeData(color: contentColor, size: 15),
      child: leading ?? const SizedBox(),
    );
    var trailing =
        widget.trailing ??
        (hover ? widget.hoverTrailing : null) ??
        const SizedBox();
    var children = [
      iconTheme,
      if (leading != null) const SizedBox(width: 4),
      Expanded(child: text),
      trailing,
    ];
    var container = AnimatedContainer(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AthenaRadius.row),
      ),
      duration: duration,
      // Claude 实测行高 26，这里给**固定高度**而不是靠垂直内边距撑：
      // hover 才出现的 `⋮` 按钮高 20，比标签的行盒（约 17）高，靠内容撑会把
      // 整行从 25 顶到 28——就是"hover 上去整行变高"的原因。
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Row(children: children),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }
}
