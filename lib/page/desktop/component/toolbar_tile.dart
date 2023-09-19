import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ToolbarTile extends StatefulWidget {
  const ToolbarTile({super.key, this.color, required this.icon, this.onTap});

  final Color? color;
  final Icon icon;
  final void Function()? onTap;

  @override
  State<ToolbarTile> createState() => _ToolbarTileState();
}

class _ToolbarTileState extends State<ToolbarTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadow = colorScheme.shadow;
    final onSurface = colorScheme.onSurface;
    var color = widget.color ?? shadow.withOpacity(0.05);

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: handleEnter,
        onExit: handleExit,
        child: Container(
          alignment: Alignment.center,
          color: hover ? color : null,
          height: 24,
          width: 40,
          child: IconTheme(
            data: IconThemeData(size: 20, color: onSurface),
            child: widget.icon,
          ),
        ),
      ),
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
