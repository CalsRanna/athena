import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

class AthenaBottomSheetTile extends StatelessWidget {
  final bool enabled;
  final Widget? leading;
  final void Function()? onTap;
  final bool selected;
  final String title;
  final Widget? trailing;
  const AthenaBottomSheetTile({
    super.key,
    this.enabled = true,
    this.leading,
    this.onTap,
    this.selected = false,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textColor = enabled ? colors.textPrimary : colors.textSecondary;
    final textStyle = AthenaTextStyle.body.copyWith(
      color: textColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
    final trailingTextStyle = AthenaTextStyle.body.copyWith(color: textColor);
    final iconColor = enabled ? colors.iconSecondary : colors.textSecondary;
    final leadingIconThemeData = IconThemeData(color: iconColor);
    final trailingIconThemeData = IconThemeData(color: textColor);
    final trailingIconTheme = IconTheme(
      data: trailingIconThemeData,
      child: trailing ?? const SizedBox(),
    );
    final defaultTrailing = DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: trailingTextStyle,
      child: trailingIconTheme,
    );
    final align = Align(
      alignment: Alignment.centerRight,
      child: defaultTrailing,
    );
    final children = [
      IconTheme(data: leadingIconThemeData, child: leading ?? const SizedBox()),
      if (leading != null) const SizedBox(width: 12),
      Text(title, style: textStyle),
      if (trailing != null) const SizedBox(width: 12),
      Flexible(child: align),
    ];
    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: container,
    );
  }
}
