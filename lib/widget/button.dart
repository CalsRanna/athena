import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  const AIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hugeIcon = HugeIcon(icon: icon, color: const Color(0xff000000));
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: button,
    );
  }
}

class APrimaryButton extends StatelessWidget {
  final void Function()? onTap;
  final Widget child;
  const APrimaryButton({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: Color(0xFFCED2C7).withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: Color(0xffffffff),
      shape: StadiumBorder(),
      shadows: [boxShadow],
    );
    var container = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}

class AOutlinedButton extends StatelessWidget {
  final void Function()? onTap;
  final Widget child;
  const AOutlinedButton({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: Color(0xFFC2C2C2))),
    );
    var container = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
