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
