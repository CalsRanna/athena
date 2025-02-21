import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final double? width;
  final List<Widget> children;
  const DesktopContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.width,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildBarrier(),
      Positioned(left: offset.dx, top: offset.dy, child: _buildMenu(context)),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: onBarrierTapped,
      onTap: onBarrierTapped,
      child: Stack(children: children),
    );
  }

  Widget _buildBarrier() => const SizedBox.expand();

  Widget _buildMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final shadow = colorScheme.shadow.withValues(alpha: 0.1);
    final boxShadow = BoxShadow(color: shadow, blurRadius: 12, spreadRadius: 4);
    var boxDecoration = BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [boxShadow],
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: width,
      child: Column(children: children),
    );
  }
}

class DesktopContextMenuOption extends StatefulWidget {
  final void Function()? onTap;
  final String text;

  const DesktopContextMenuOption({super.key, this.onTap, required this.text});

  @override
  State<DesktopContextMenuOption> createState() =>
      _DesktopContextMenuOptionState();
}

class DesktopMenuTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);
    var textStyle = TextStyle(
      color: active ? Color(0xFF161616) : Colors.white,
      fontSize: 14,
      height: 1.5,
    );
    var animatedText = AnimatedDefaultTextStyle(
      duration: duration,
      style: textStyle,
      child: Text(label),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(35),
      color: active ? Color(0xFFE0E0E0) : Color(0xFF616161),
    );
    var iconThemeData = IconThemeData(
      color: active ? Color(0xFF161616) : Colors.white,
      size: 16,
    );
    var iconTheme = IconTheme(
      data: iconThemeData,
      child: leading ?? const SizedBox(),
    );
    var children = [
      iconTheme,
      if (leading != null) const SizedBox(width: 4),
      Expanded(child: animatedText),
      trailing ?? const SizedBox(),
    ];
    var animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: duration,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: children),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: animatedContainer,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onSecondaryTap,
      onTap: onTap,
      child: mouseRegion,
    );
  }
}

class _DesktopContextMenuOptionState extends State<DesktopContextMenuOption> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final surfaceContainer = colorScheme.surfaceContainer;
    var textStyle = TextStyle(
      color: onSurface,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? surfaceContainer : null,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: 100,
      child: Text(widget.text, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent _) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent _) {
    setState(() {
      hover = false;
    });
  }
}
