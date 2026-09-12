import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

/// 首页卡片行中的单张卡片（恢复原 Shortcut 卡片样式：
/// 160×160、圆角 24、surfaceButtonSecondary、图标 + 名称 + 描述）。
class CardTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final void Function()? onTap;

  const CardTile({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    this.onTap,
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
        padding: const EdgeInsets.all(12),
        height: 160,
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.textPrimary),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                description,
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

/// 横向卡片行容器（首页使用）。
class CardListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const CardListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }
}
