import 'package:athena/model/shortcut.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class ShortcutTile extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final Shortcut shortcut;

  const ShortcutTile({
    super.key,
    required this.icon,
    this.onTap,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: ColorUtil.FF616161,
        ),
        padding: EdgeInsets.all(12),
        height: 160,
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ColorUtil.FFFFFFFF),
            const SizedBox(height: 4),
            Text(
              shortcut.name,
              style: const TextStyle(
                color: ColorUtil.FFFFFFFF,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                shortcut.description,
                style: const TextStyle(
                  color: ColorUtil.FFE0E0E0,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
