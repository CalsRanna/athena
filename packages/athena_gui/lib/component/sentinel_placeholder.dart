import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 会话空态：当前角色的头像、名称、说明与标签。
///
/// 结构对齐空态实测规格：48 逻辑图标 → 约 28 间距 → 24 号标题 → 说明 → 标签。
///
/// 桌面与移动此前各写了一份并已漂移——移动端停在旧规格（28/w700 标题、
/// 说明取 `border` 色、没有头像与标签），修一处漏一处的风险很高，故合并为
/// 唯一实现，两端外观以本规格为准。
class SentinelPlaceholder extends StatelessWidget {
  /// 可空：移动端在角色解析完成前就会渲染这一屏。
  final SentinelEntity? sentinel;

  const SentinelPlaceholder({super.key, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final sentinel = this.sentinel;
    if (sentinel == null) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AthenaColors>()!;
    var nameTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaFontSize.hero,
      // hero = 24，对齐空态标题的实测字号（旧版 28 偏大）
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    var descriptionTextStyle = TextStyle(
      color: colors.textSecondary,
      fontSize: AthenaFontSize.body,
      fontWeight: FontWeight.w400,
    );
    var children = [
      _Glyph(sentinel: sentinel),
      const SizedBox(height: 28),
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

/// 空态顶部图标：用当前 Sentinel 的头像（自定义角色用 emoji，内置角色用应用图标）。
class _Glyph extends StatelessWidget {
  final SentinelEntity sentinel;

  const _Glyph({required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    const size = 48.0;
    if (sentinel.name != 'Athena' && sentinel.avatar.isNotEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.avatarBackground,
        ),
        height: size,
        width: size,
        child: Text(
          sentinel.avatar,
          maxLines: 1,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, height: 1),
        ),
      );
    }
    return ClipOval(
      child: Image.asset(
        'asset/image/launcher_icon_ios_512x512.jpg',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        height: size,
        width: size,
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
    var textStyle = TextStyle(
      color: colors.textSecondary,
      fontSize: AthenaFontSize.label,
      fontWeight: FontWeight.w500,
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
