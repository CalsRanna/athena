import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class DesktopSentinelPlaceholder extends StatelessWidget {
  final Sentinel sentinel;
  const DesktopSentinelPlaceholder({super.key, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    var nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    var descriptionTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var descriptionText = Text(
      sentinel.description,
      style: descriptionTextStyle,
      textAlign: TextAlign.center,
    );
    var children = [
      Text(sentinel.name, style: nameTextStyle),
      const SizedBox(height: 12),
      _TagWrap(sentinel: sentinel),
      const SizedBox(height: 12),
      descriptionText,
    ];
    var column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: column,
    );
  }
}

class _TagWrap extends StatelessWidget {
  final Sentinel sentinel;

  const _TagWrap({required this.sentinel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: sentinel.tags.map(_buildTile).toList(),
    );
  }

  Widget _buildTile(String tag) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: ColorUtil.FF161616,
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
      child: Text(tag, style: textStyle),
    );
    var colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      ColorUtil.FFFFFFFF.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}
