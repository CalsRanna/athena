import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';

/// 桌面左侧栏/列表行：整行 hover 底色 + 选中行提亮，圆角 [AthenaRadius.row]，
/// 没有渐变边框。
class DesktopMenuTile extends StatefulWidget {
  final bool active;
  final String label;
  final Widget? leading;
  final void Function(TapUpDetails)? onSecondaryTap;
  final void Function()? onTap;
  final Widget? trailing;

  /// 仅在 hover 时出现的尾部（会话行 hover 才显示 `⋮`）。
  final Widget? hoverTrailing;

  /// 需要感知 hover 的 leading（状态点在 hover 时会加深）。
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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // hover 只改底色，文字不动；选中行才使用青瓷强调。
    // 旧版在 hover 时把标签从次级灰跳到近黑，观感是"文字闪一下"，是错的。
    var contentColor = widget.active ? colors.accent : colors.textRowLabel;
    // 列表行与输入框、菜单统一采用 14 / 22 的常规 UI 档。
    var textStyle = AthenaTextStyle.body.copyWith(
      color: contentColor,
      fontWeight: FontWeight.w400,
    );
    var text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    return AthenaHover(
      onTap: widget.onTap,
      onSecondaryTap: widget.onSecondaryTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) {
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
          data: IconThemeData(
            color: contentColor,
            size: AthenaIcon.regularSize,
          ),
          child: leading ?? const SizedBox(),
        );
        var trailing =
            widget.trailing ??
            (hover ? widget.hoverTrailing : null) ??
            const SizedBox();
        return AnimatedContainer(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AthenaRadius.row),
          ),
          duration: AthenaMotion.hover,
          // 固定高保证 hover 出现的操作按钮不改变行高，文字上下各留 5。
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(
            children: [
              iconTheme,
              if (leading != null) const SizedBox(width: 8),
              Expanded(child: text),
              trailing,
            ],
          ),
        );
      },
    );
  }
}
