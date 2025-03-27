import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final double width;
  final List<Widget> children;
  const DesktopContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.width = 120,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      const SizedBox.expand(),
      Positioned(left: offset.dx, top: offset.dy, child: _buildMenu(context)),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: onBarrierTapped,
      onTap: onBarrierTapped,
      child: Stack(children: children),
    );
  }

  Widget _buildMenu(BuildContext context) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: column,
    );
    return DesktopContextMenuConfiguration(width: width, child: container);
  }
}

class DesktopContextMenuConfiguration extends InheritedWidget {
  final double width;
  const DesktopContextMenuConfiguration({
    super.key,
    required this.width,
    required super.child,
  });

  @override
  bool updateShouldNotify(
    covariant DesktopContextMenuConfiguration oldWidget,
  ) {
    return oldWidget.width != width;
  }

  static double widthOf(BuildContext context) {
    var widget = context
        .dependOnInheritedWidgetOfExactType<DesktopContextMenuConfiguration>();
    return widget!.width;
  }
}

class DesktopContextMenuTile extends StatefulWidget {
  final void Function()? onTap;
  final String text;

  const DesktopContextMenuTile({super.key, this.onTap, required this.text});

  @override
  State<DesktopContextMenuTile> createState() => _DesktopContextMenuTileState();
}

class _DesktopContextMenuTileState extends State<DesktopContextMenuTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? ColorUtil.FF616161 : null,
    );
    var width = DesktopContextMenuConfiguration.widthOf(context);
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: width,
      child: Text(widget.text, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
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
