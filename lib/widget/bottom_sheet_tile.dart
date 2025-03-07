import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaBottomSheetTile extends StatelessWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String title;
  final Widget? trailing;
  const AthenaBottomSheetTile({
    super.key,
    this.leading,
    this.onTap,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var trailingTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var leadingIconThemeData = IconThemeData(color: ColorUtil.FFE0E0E0);
    var trailingIconThemeData = IconThemeData(color: ColorUtil.FFFFFFFF);
    var trailingIconTheme = IconTheme(
      data: trailingIconThemeData,
      child: trailing ?? const SizedBox(),
    );
    var defaultTrailing = DefaultTextStyle.merge(
      style: trailingTextStyle,
      child: trailingIconTheme,
    );
    var children = [
      IconTheme(data: leadingIconThemeData, child: leading ?? const SizedBox()),
      if (leading != null) const SizedBox(width: 12),
      Expanded(child: Text(title, style: textStyle)),
      if (trailing != null) const SizedBox(width: 12),
      defaultTrailing,
    ];
    var container = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
