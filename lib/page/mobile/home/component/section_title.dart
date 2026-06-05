import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class SectionTitle extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  const SectionTitle(this.title, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(child: Text(title, style: textStyle)),
      _buildMoreButton(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    );
  }

  Widget _buildMoreButton() {
    var container = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorUtil.FFFFFFFF,
      ),
      padding: EdgeInsets.all(12),
      child: Icon(HugeIcons.strokeRoundedArrowRight02, size: 16),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
