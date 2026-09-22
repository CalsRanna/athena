import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 首页卡片行中的单张卡片：160×160、圆角 [AthenaRadius.container]、
/// `surfaceButtonSecondary` 底、图标 + 名称 + 描述。
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
          borderRadius: BorderRadius.circular(AthenaRadius.container),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AthenaTextStyle.section.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                description,
                style: AthenaTextStyle.caption.copyWith(
                  color: colors.iconSecondary,
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
