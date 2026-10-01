import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 会话空态：当前角色的名称、说明与标签，桌面与移动共用同一版式。
class SentinelPlaceholder extends StatelessWidget {
  /// 可空：移动端在角色解析完成前就会渲染这一屏。
  final SentinelEntity? sentinel;

  const SentinelPlaceholder({super.key, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final sentinel = this.sentinel;
    if (sentinel == null) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AthenaColors>()!;
    final nameTextStyle = AthenaTextStyle.hero.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final descriptionTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
    );
    final children = [
      Text(sentinel.name, style: nameTextStyle, textAlign: TextAlign.center),
      if (sentinel.description.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          sentinel.description,
          style: descriptionTextStyle,
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 18),
      _TagWrap(sentinel: sentinel),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  final SentinelEntity sentinel;

  const _TagWrap({required this.sentinel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: sentinel.tagList
          .map((tag) => _buildTile(context, tag))
          .toList(),
    );
  }

  Widget _buildTile(BuildContext context, String tag) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.label.copyWith(
      color: colors.textSecondary,
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceButtonSecondary,
        borderRadius: BorderRadius.circular(AthenaRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(tag, style: textStyle),
    );
  }
}
