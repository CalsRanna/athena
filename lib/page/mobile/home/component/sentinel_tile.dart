import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';

import 'package:flutter/material.dart';

class SentinelTile extends StatelessWidget {
  final SentinelEntity sentinel;
  const SentinelTile(this.sentinel, {super.key});

  @override
  Widget build(BuildContext context) {
    const innerDecoration = ShapeDecoration(
      color: ColorUtil.FF161616,
      shape: StadiumBorder(),
    );
    const textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final innerContainer = Container(
      alignment: Alignment.center,
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
      child: Text(sentinel.name, style: textStyle),
    );
    final colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      Colors.transparent,
    ];
    final linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateChatPage(context),
      child: Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(1),
        child: innerContainer,
      ),
    );
  }

  void navigateChatPage(BuildContext context) {
    MobileChatRoute(sentinel: sentinel).push(context);
  }
}
