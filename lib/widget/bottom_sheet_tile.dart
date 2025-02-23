import 'package:flutter/material.dart';

class ABottomSheetTile extends StatelessWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String title;
  const ABottomSheetTile({
    super.key,
    this.leading,
    this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var iconThemeData = IconThemeData(color: Color(0xFFE0E0E0));
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
