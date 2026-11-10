import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/widgets.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 桌面左侧栏/列表行：整行 hover 底色 + 选中行提亮，圆角 [AthenaRadius.row]，
/// 没有渐变边框。
class DesktopMenuTile extends StatefulWidget {
  final bool active;
  final String label;
  final Widget? leading;
  final void Function(TapUpDetails)? onSecondaryTap;
  final void Function()? onTap;

  /// 尾部内容；[hover] 是整行的 hover 状态。尾部只有一份内容，需要在 hover 时
  /// 换内容的行（会话行静止显示运行状态点、hover 换成 `⋮`）在这里分支即可。
  final Widget Function(bool hover)? trailingBuilder;

  const DesktopMenuTile({
    super.key,
    required this.active,
    required this.label,
    this.leading,
    this.onSecondaryTap,
    this.onTap,
    this.trailingBuilder,
  });

  @override
  State<DesktopMenuTile> createState() => _DesktopMenuTileState();
}

class _DesktopMenuTileState extends State<DesktopMenuTile> {
  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    // hover 只改底色，文字不动；选中行才使用青瓷强调。
    final contentColor = widget.active ? colors.accent : colors.textRowLabel;
    // 列表行与输入框、菜单统一采用 14 / 22 的常规 UI 档。
    final textStyle = AthenaTextStyle.body.copyWith(color: contentColor);
    final text = Text(
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
        final resting = colors.surfaceHover.withValues(alpha: 0);
        final background = widget.active
            ? colors.surfaceSelected
            : hover
            ? colors.surfaceHover
            : resting;
        final leading = widget.leading;
        final iconTheme = IconTheme(
          data: IconThemeData(
            color: contentColor,
            size: AthenaIcon.regularSize,
          ),
          child: leading ?? const SizedBox(),
        );
        final trailing =
            widget.trailingBuilder?.call(hover) ?? const SizedBox();
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
