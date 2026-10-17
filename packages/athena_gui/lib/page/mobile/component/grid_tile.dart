import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 移动端网格里的实体卡（Skill / Sentinel / Experience 列表共用）。
///
/// 中性色块底（`surfaceButtonSecondary`）+ 1px `border` +
/// [AthenaRadius.container] 圆角 + 内边距 12；标题
/// [AthenaTextStyle.section]、副标题 [AthenaTextStyle.caption]，分别用
/// `textPrimary` / `textSecondary`。[trailing] 排在标题行末尾（内置锁、
/// 归档标之类），图标默认 14、用 `iconSecondary`。
///
/// 不用反色面（`surfaceRaised`）：那是小型指示块与提示框的语言，铺成
/// 列表卡片会在浅色主题下变成一排深色块、深色主题下变成一排浅色块。
class MobileGridTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final int? titleMaxLines;
  final int? subtitleMaxLines;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MobileGridTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final subtitleStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
    );
    final titleChildren = [
      Expanded(
        child: Text(
          title,
          maxLines: titleMaxLines,
          overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
          style: titleStyle,
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        IconTheme.merge(
          data: IconThemeData(
            color: colors.iconSecondary,
            size: AthenaIcon.inlineSize,
          ),
          child: trailing!,
        ),
      ],
    ];
    final children = [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: titleChildren,
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        maxLines: subtitleMaxLines,
        overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
        style: subtitleStyle,
      ),
    ];
    final container = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AthenaRadius.container),
        color: colors.surfaceButtonSecondary,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: container,
    );
  }
}
