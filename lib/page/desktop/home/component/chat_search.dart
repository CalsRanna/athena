import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopChatSearch extends StatelessWidget {
  const DesktopChatSearch({super.key});

  @override
  Widget build(BuildContext context) {
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Search',
      hintStyle: TextStyle(color: ColorUtil.FFC2C2C2, fontSize: 14),
    );
    var textField = TextField(
      cursorColor: ColorUtil.FFFFFFFF,
      decoration: inputDecoration,
      style: const TextStyle(fontSize: 14),
    );
    var hugeIcon = HugeIcon(
      color: ColorUtil.FFC2C2C2,
      icon: HugeIcons.strokeRoundedSearch01,
      size: 24,
    );
    var children = [
      hugeIcon,
      const SizedBox(width: 10),
      Expanded(child: textField),
    ];
    var boxDecoration = BoxDecoration(
      border: Border.all(color: Color(0xFF757575)),
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(56),
    );
    return Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: children),
    );
  }
}
