import 'package:athena/schema/summary.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class MobileSummaryListTile extends StatelessWidget {
  final void Function()? onTap;
  final Summary summary;

  const MobileSummaryListTile({
    super.key,
    this.onTap,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var titleText = Text(
      summary.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleTextStyle,
    );
    var linkTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var linkText = Text(
      summary.link,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: linkTextStyle,
    );
    var contentTextStyle = TextStyle(
      color: ColorUtil.FFA7BA88,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var content = summary.content.isNotEmpty ? summary.content : summary.html;
    content = content.replaceAll('\n', '');
    content = content.replaceAll(' ', '');
    var contentText = Text(
      content,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: contentTextStyle,
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [titleText, linkText, contentText],
    );
    var rowChildren = [
      _buildLogo(),
      SizedBox(width: 20),
      Expanded(child: column),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(children: rowChildren),
    );
  }

  Widget _buildLogo() {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FFADADAD,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedAiBrowser,
      color: ColorUtil.FFFFFFFF,
      size: 32,
    );
    return Container(
      decoration: boxDecoration,
      height: 80,
      width: 80,
      child: icon,
    );
  }
}
