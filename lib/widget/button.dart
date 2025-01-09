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
  const APrimaryButton({super.key, this.onTap, required this.child});

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

class ASecondaryButton extends StatelessWidget {
  final void Function()? onTap;
  final Widget child;
  const ASecondaryButton({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: Color(0xFFC2C2C2))),
    );
    const defaultTextStyle = TextStyle(color: Colors.white);
    var container = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: DefaultTextStyle(style: defaultTextStyle, child: child),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}

class ATextButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const ATextButton({super.key, this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    const defaultTextStyle = TextStyle(color: Color(0xFFA7BA88));
    var container = Container(
      decoration: ShapeDecoration(shape: StadiumBorder()),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: DefaultTextStyle(style: defaultTextStyle, child: Text(text)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
