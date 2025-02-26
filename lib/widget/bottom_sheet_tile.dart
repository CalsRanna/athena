import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaBottomSheetTile extends StatelessWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String title;
  const AthenaBottomSheetTile({
    super.key,
    this.leading,
    this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var iconThemeData = IconThemeData(color: ColorUtil.FFE0E0E0);
    var children = [
      IconTheme(data: iconThemeData, child: leading ?? const SizedBox()),
      if (leading != null) const SizedBox(width: 12),
      Text(title, style: textStyle),
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
