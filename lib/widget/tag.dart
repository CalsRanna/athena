import 'package:athena/util/color_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AthenaTag extends StatelessWidget {
  final double fontSize;
  final EdgeInsets padding;
  final bool selected;
  final String text;

  const AthenaTag({
    super.key,
    this.fontSize = 12,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 36, vertical: 13);

  const AthenaTag.small({
    super.key,
    this.fontSize = 12,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4);

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: selected ? ColorUtil.FF161616 : ColorUtil.FFFFFFFF,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var animatedText = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: textStyle,
      child: Text(text),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(44),
      color: selected ? ColorUtil.FFE0E0E0 : ColorUtil.FF161616,
    );
    var innerContainer = AnimatedContainer(
      decoration: innerBoxDecoration,
      duration: const Duration(milliseconds: 300),
      padding: padding,
      child: animatedText,
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
      borderRadius: BorderRadius.circular(44),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}

class AthenaTagButton extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final void Function()? onTap;
  final bool selected;

  const AthenaTagButton({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  }) : padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  const AthenaTagButton.small({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  @override
  State<AthenaTagButton> createState() => _AthenaTagButtonState();
}

class _AthenaTagButtonState extends State<AthenaTagButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var selected = widget.selected;
    var foregroundColor = selected ? ColorUtil.FF161616 : ColorUtil.FFFFFFFF;
    var innerColor = selected ? ColorUtil.FFE0E0E0 : ColorUtil.FF161616;
    var gradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: [
        ColorUtil.FFEAEAEA.withValues(alpha: hover ? 0.28 : 0.17),
        ColorUtil.FFFFFFFF.withValues(alpha: hover ? 0.04 : 0),
      ],
      end: Alignment.bottomRight,
    );
    var child = DefaultTextStyle.merge(
      style: TextStyle(
        color: foregroundColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foregroundColor, size: 14),
        child: widget.child,
      ),
    );
    var innerContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(44),
        color: innerColor,
      ),
      padding: widget.padding,
      child: child,
    );
    var outerContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(44),
        gradient: gradient,
      ),
      padding: const EdgeInsets.all(1),
      child: innerContainer,
    );
    var mouseRegion = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: _handleEnter,
      onExit: _handleExit,
      child: outerContainer,
    );
    if (widget.onTap == null) return mouseRegion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void _handleEnter(PointerEnterEvent event) {
    if (!mounted) return;
    setState(() {
      hover = true;
    });
  }

  void _handleExit(PointerExitEvent event) {
    if (!mounted) return;
    setState(() {
      hover = false;
    });
  }
}
