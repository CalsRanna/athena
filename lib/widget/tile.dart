import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: ColorUtil.FFFFFFFF,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: ColorUtil.FFE0E0E0,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var titleChildren = [
      Text(title, style: titleTextStyle),
      if (subtitle != null) Text(subtitle!, style: subtitleTextStyle),
    ];
    var titleColumn = Column(
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
    var tileChildren = [
      leading ?? const SizedBox(),
      if (leading != null) const SizedBox(width: 12),
      Expanded(child: titleColumn),
      trailingText,
      Icon(HugeIcons.strokeRoundedArrowRight01),
    ];
    var tileRow = IconTheme(
      data: const IconThemeData(color: ColorUtil.FFE0E0E0, size: 16),
      child: Row(children: tileChildren),
    );
    return ListTile(title: tileRow, onTap: onTap);
  }
}
