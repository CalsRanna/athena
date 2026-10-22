import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 首页卡片行中的单张卡片：宽 160、圆角 [AthenaRadius.container]、
/// `surfaceButtonSecondary` 底 + 1px `border`、图标 + 名称 + 描述。
///
/// 高度由 [CardListView] 按当前字号计算后统一约束，卡片内部不再写死 160，
/// 避免系统大字号下名称与描述把固定高度撑破。
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
    final colors = context.athenaColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AthenaRadius.container),
          color: colors.surfaceButtonSecondary,
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(12),
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.textPrimary),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AthenaTextStyle.section.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AthenaTextStyle.caption.copyWith(
                color: colors.iconSecondary,
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
    // 卡片高度按当前字号计算：图标行 + 两行标题 + 三行描述 + 内边距。
    // 160 是常规字号下的下限，大字号时随之增高，卡片内容不会溢出。
    final scaler = MediaQuery.textScalerOf(context);
    final titleLine =
        scaler.scale(AthenaFontSize.section) * AthenaFontSize.bodyHeight;
    final captionLine =
        scaler.scale(AthenaFontSize.caption) * AthenaFontSize.captionHeight;
    final contentHeight =
        24 + AthenaIcon.regularSize + 4 + titleLine * 2 + 4 + captionLine * 3;
    final height = contentHeight < 160 ? 160.0 : contentHeight;
    return SizedBox(
      height: height,
      child: ListView.separated(
        itemBuilder: itemBuilder,
        itemCount: itemCount,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
      ),
    );
  }
}
