import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final EdgeInsets? padding;
  const AthenaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hugeIcon = Icon(icon, color: ColorUtil.FF000000, size: 16);
    const boxDecoration = BoxDecoration(
      color: ColorUtil.FFFFFFFF,
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

class AthenaPrimaryButton extends StatelessWidget {
  final void Function()? onTap;
  final Widget child;
  const AthenaPrimaryButton({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
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

class AthenaSecondaryButton extends StatelessWidget {
  final void Function()? onTap;
  final EdgeInsets padding;
  final Widget child;

  const AthenaSecondaryButton({super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  const AthenaSecondaryButton.medium(
      {super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  const AthenaSecondaryButton.small(
      {super.key, this.onTap, required this.child})
      : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  @override
  Widget build(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: ColorUtil.FFC2C2C2)),
    );
    const defaultTextStyle = TextStyle(color: ColorUtil.FFFFFFFF);
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

class AthenaTextButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const AthenaTextButton({super.key, this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    const defaultTextStyle = TextStyle(color: ColorUtil.FFFFFFFF);
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
