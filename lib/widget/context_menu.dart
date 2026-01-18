import 'dart:async';

import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopContextMenu extends StatelessWidget {
  final Offset offset;
  final double width;
  final List<Widget> children;
  const DesktopContextMenu({
    super.key,
    required this.offset,
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
      onSecondaryTap: dismissContextMenu,
      onTap: dismissContextMenu,
      child: Stack(children: children),
    );
  }

  void dismissContextMenu() {
    DesktopContextMenuManager.instance.dismiss();
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
  bool updateShouldNotify(covariant DesktopContextMenuConfiguration oldWidget) {
    return oldWidget.width != width;
  }

  static double widthOf(BuildContext context) {
    var widget = context
        .dependOnInheritedWidgetOfExactType<DesktopContextMenuConfiguration>();
    return widget!.width;
  }
}

class DesktopContextMenuTile extends StatefulWidget {
  final bool enabled;
  final void Function()? onTap;
  final String text;

  const DesktopContextMenuTile({
    super.key,
    this.enabled = true,
    this.onTap,
    required this.text,
  });

  @override
  State<DesktopContextMenuTile> createState() => _DesktopContextMenuTileState();
}

class _DesktopContextMenuTileState extends State<DesktopContextMenuTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var textColor = widget.enabled ? ColorUtil.FFFFFFFF : ColorUtil.FF9E9E9E;
    var textStyle = TextStyle(
      color: textColor,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover && widget.enabled ? ColorUtil.FF616161 : null,
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
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? handleTap : null,
      child: mouseRegion,
    );
  }

  void handleTap() {
    DesktopContextMenuManager.instance.dismiss();
    widget.onTap?.call();
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

class DesktopContextMenuSubItem extends StatefulWidget {
  final String text;
  final void Function()? onTap;

  const DesktopContextMenuSubItem({super.key, required this.text, this.onTap});

  @override
  State<DesktopContextMenuSubItem> createState() =>
      _DesktopContextMenuSubItemState();
}

class _DesktopContextMenuSubItemState extends State<DesktopContextMenuSubItem> {
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
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      onTap: () {
        DesktopContextMenuManager.instance.dismiss();
        widget.onTap?.call();
      },
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}

class DesktopContextMenuTileWithSubmenu extends StatefulWidget {
  final bool enabled;
  final String text;
  final List<DesktopContextMenuSubItem> submenuItems;

  const DesktopContextMenuTileWithSubmenu({
    super.key,
    this.enabled = true,
    required this.text,
    required this.submenuItems,
  });

  @override
  State<DesktopContextMenuTileWithSubmenu> createState() =>
      _DesktopContextMenuTileWithSubmenuState();
}

class _DesktopContextMenuTileWithSubmenuState
    extends State<DesktopContextMenuTileWithSubmenu> {
  bool hover = false;
  bool submenuHover = false;
  OverlayEntry? _submenuEntry;
  Timer? _hideTimer;

  @override
  Widget build(BuildContext context) {
    var textColor = widget.enabled ? ColorUtil.FFFFFFFF : ColorUtil.FF9E9E9E;
    var textStyle = TextStyle(
      color: textColor,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover && widget.enabled ? ColorUtil.FF616161 : null,
    );
    var width = DesktopContextMenuConfiguration.widthOf(context);
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.text, style: textStyle),
        Icon(Icons.chevron_right, color: textColor, size: 16),
      ],
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: width,
      child: row,
    );
    var mouseRegion = MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: widget.enabled ? handleEnter : null,
      onExit: widget.enabled ? handleExit : null,
      child: container,
    );
    return mouseRegion;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _submenuEntry?.remove();
    _submenuEntry = null;
    super.dispose();
  }

  void handleEnter(PointerEnterEvent event) {
    _hideTimer?.cancel();
    setState(() => hover = true);
    _showSubmenu(event);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
    // 延迟隐藏子菜单，给用户时间移动鼠标到子菜单
    _hideTimer = Timer(const Duration(milliseconds: 100), () {
      if (!submenuHover) {
        _hideSubmenu();
      }
    });
  }

  void _showSubmenu(PointerEnterEvent event) {
    _hideSubmenu();
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final width = DesktopContextMenuConfiguration.widthOf(context);

    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.submenuItems,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      width: 168,
      child: column,
    );

    _submenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: offset.dx + width + 8,
            top: offset.dy,
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) {
                  _hideTimer?.cancel();
                  submenuHover = true;
                },
                onExit: (_) {
                  submenuHover = false;
                  _hideSubmenu();
                },
                child: container,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_submenuEntry!);
  }

  void _hideSubmenu() {
    _hideTimer?.cancel();
    _submenuEntry?.remove();
    _submenuEntry = null;
  }
}

class DesktopContextMenuManager {
  OverlayEntry? _entry;
  static DesktopContextMenuManager instance = DesktopContextMenuManager();
  void show(BuildContext context, Widget contextMenu) {
    if (_entry != null) _entry!.remove();
    _entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(_entry!);
  }

  void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}
