import 'package:flutter/material.dart';

class AIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final EdgeInsets? padding;
  const AIconButton({super.key, required this.icon, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    final hugeIcon = Icon(icon, color: const Color(0xff000000), size: 16);
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: padding ?? const EdgeInsets.all(12),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: button),
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
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
  }
}

class ASecondaryButton extends StatelessWidget {
  final void Function()? onTap;
  final EdgeInsets padding;
  final Widget child;

  const ASecondaryButton({super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  const ASecondaryButton.medium({super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  const ASecondaryButton.small({super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  @override
  Widget build(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: Color(0xFFC2C2C2))),
    );
    const defaultTextStyle = TextStyle(color: Colors.white);
    var container = Container(
      decoration: shapeDecoration,
      padding: padding,
      child: DefaultTextStyle(style: defaultTextStyle, child: child),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
  }
}

class ATextButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const ATextButton({super.key, this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    const defaultTextStyle = TextStyle(color: Color(0xFFFFFFFF));
    var container = Container(
      decoration: ShapeDecoration(shape: StadiumBorder()),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: DefaultTextStyle(style: defaultTextStyle, child: Text(text)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
  }
}
