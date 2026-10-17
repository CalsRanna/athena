import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 移动设置页的一个分区：标题 + 可选说明 + 一张分组卡片。
///
/// 与桌面 `AthenaSettingsSection` 同一语义，但移动端用整页单列布局：
/// 标题在卡片外，卡片包住连续设置行，行间画发丝线。
class MobileSettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const MobileSettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleStyle = AthenaTextStyle.title.copyWith(
      color: colors.textPrimary,
    );
    final descriptionStyle = AthenaTextStyle.row.copyWith(
      color: colors.textSecondary,
    );
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Divider(height: 1, thickness: 1, color: colors.border),
          ),
        );
      }
      rows.add(children[i]);
    }
    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.surfaceMobile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AthenaRadius.container),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AthenaSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: titleStyle),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(description!, style: descriptionStyle),
            ),
          ],
          const SizedBox(height: AthenaSpace.md),
          card,
        ],
      ),
    );
  }
}
