import 'package:athena/page/desktop/component/toolbar_tile.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class Toolbar extends StatefulWidget {
  const Toolbar({super.key});

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ToolbarTile(icon: const Icon(Icons.remove_outlined), onTap: minimize),
            ToolbarTile(
              color: Colors.red,
              icon: const Icon(Icons.close_outlined),
              onTap: close,
            ),
          ],
        ),
      ),
    );
  }

  void minimize() {
    windowManager.minimize();
  }

  void close() {
    windowManager.close();
  }
}
