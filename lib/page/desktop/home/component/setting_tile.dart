import 'package:athena/router/router.gr.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopSettingTile extends StatelessWidget {
  const DesktopSettingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: HugeIcons.strokeRoundedSettings01,
      onTap: () => handleTap(context),
      title: 'Setting',
    );
  }

  void handleTap(BuildContext context) {
    const DesktopSettingAccountRoute().push(context);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final String title;
  const _Tile({required this.icon, this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    var children = [
      Icon(icon, color: Colors.white, size: 24),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(color: Colors.white))),
      const SizedBox(width: 12),
      Icon(HugeIcons.strokeRoundedArrowRight01, color: Colors.white, size: 16),
    ];
    var padding = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: padding,
    );
  }
}
