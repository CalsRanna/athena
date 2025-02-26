import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class ACard extends StatelessWidget {
  final BorderRadius? borderRadius;
  final double? width;
  final Widget child;
  const ACard({super.key, this.borderRadius, this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: width,
      child: child,
    );
  }
}
