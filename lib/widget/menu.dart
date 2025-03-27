import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopMenuTile extends StatefulWidget {
  final bool active;
  final String label;
  final Widget? leading;
  final void Function(TapUpDetails)? onSecondaryTap;
  final void Function()? onTap;
  final Widget? trailing;
  const DesktopMenuTile({
    super.key,
    required this.active,
    required this.label,
    this.leading,
    this.onSecondaryTap,
    this.onTap,
    this.trailing,
  });

  @override
  State<DesktopMenuTile> createState() => _DesktopMenuTileState();
}

class _DesktopMenuTileState extends State<DesktopMenuTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );
    var text = Text(
      widget.label,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    var innerShapeDecoration = ShapeDecoration(
      color: widget.active ? ColorUtil.FF9E9E9E : ColorUtil.FF616161,
      shape: StadiumBorder(),
    );
    var iconThemeData = IconThemeData(color: ColorUtil.FFFFFFFF, size: 16);
    var iconTheme = IconTheme(
      data: iconThemeData,
      child: widget.leading ?? const SizedBox(),
    );
    var children = [
      iconTheme,
      if (widget.leading != null) const SizedBox(width: 4),
      Expanded(child: text),
      widget.trailing ?? const SizedBox(),
    ];
    var innerContainer = AnimatedContainer(
      decoration: innerShapeDecoration,
      duration: duration,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: children),
    );
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: [ColorUtil.FFEAEAEA.withValues(alpha: 0.17), Colors.transparent],
      end: Alignment.bottomRight,
    );
    var outerShapeDecoration = ShapeDecoration(
      color: widget.active || hover ? ColorUtil.FFC2C2C2 : null,
      shape: StadiumBorder(),
      gradient: widget.active || hover ? null : linearGradient,
    );
    var outerContainer = Container(
      decoration: outerShapeDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: outerContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }
}
