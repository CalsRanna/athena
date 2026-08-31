import 'package:athena_gui/theme/athena_colors.dart';
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
    var textColor = enabled ? colors.textPrimary : colors.textSecondary;
    var textStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      height: 1.5,
    );
    var trailingTextStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var iconColor = enabled ? colors.iconSecondary : colors.textSecondary;
    var leadingIconThemeData = IconThemeData(color: iconColor);
    var trailingIconThemeData = IconThemeData(color: textColor);
    var trailingIconTheme = IconTheme(
      data: trailingIconThemeData,
      child: trailing ?? const SizedBox(),
    );
    var defaultTrailing = DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: trailingTextStyle,
      child: trailingIconTheme,
    );
    var align = Align(alignment: Alignment.centerRight, child: defaultTrailing);
    var children = [
      IconTheme(data: leadingIconThemeData, child: leading ?? const SizedBox()),
      if (leading != null) const SizedBox(width: 12),
      Text(title, style: textStyle),
      if (trailing != null) const SizedBox(width: 12),
      Flexible(child: align),
    ];
    var container = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: container,
    );
  }
}
