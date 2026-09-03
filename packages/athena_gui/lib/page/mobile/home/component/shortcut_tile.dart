import 'package:athena_gui/model/shortcut.dart';
import 'package:athena_gui/theme/athena_colors.dart';
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colors.surfaceButtonSecondary,
        ),
        padding: EdgeInsets.all(12),
        height: 160,
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.textPrimary),
            SizedBox(height: 4),
            Text(
              shortcut.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Expanded(
              child: Text(
                shortcut.description,
                style: TextStyle(
                  color: colors.iconSecondary,
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
