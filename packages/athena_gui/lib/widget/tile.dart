import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

class MobileSettingTile extends StatelessWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String? subtitle;
  final String title;
  final String? trailing;
  const MobileSettingTile({
    super.key,
    this.leading,
    this.onTap,
    this.subtitle,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleTextStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final subtitleTextStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
    );
    final titleChildren = [
      Text(title, style: titleTextStyle),
      if (subtitle != null) Text(subtitle!, style: subtitleTextStyle),
    ];
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: titleChildren,
    );
    final trailingText = Text(
      trailing ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: subtitleTextStyle,
      textAlign: TextAlign.end,
    );
    final tileChildren = [
      leading ?? const SizedBox(),
      if (leading != null) const SizedBox(width: 12),
      Expanded(child: titleColumn),
      trailingText,
      const Icon(AthenaIcons.forward),
    ];
    final tileRow = IconTheme(
      data: IconThemeData(
        color: colors.iconSecondary,
        size: AthenaIcon.regularSize,
      ),
      child: Row(children: tileChildren),
    );
    return ListTile(title: tileRow, onTap: onTap);
  }
}

/// 移动端网格里的实体卡（Skill / Sentinel / Experience 列表共用）。
///
/// 反色底（`surfaceRaised`）+ [AthenaRadius.container] 圆角 + 内边距 12；
/// 标题 [AthenaTextStyle.section]、副标题 [AthenaTextStyle.caption]，都是
/// `textOnRaised`。[trailing] 排在标题行末尾（内置锁、归档标之类），
/// 图标默认 14、与文字同色。
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
      color: colors.textOnRaised,
    );
    final subtitleStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textOnRaised,
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
            color: colors.textOnRaised,
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
        color: colors.surfaceRaised,
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
