import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

class DesktopSentinelPlaceholder extends StatelessWidget {
  final SentinelEntity sentinel;
  const DesktopSentinelPlaceholder({super.key, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var nameTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaFontSize.hero,
      // hero = 24，对齐 Codex 空态标题的实测字号
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    var descriptionTextStyle = TextStyle(
      color: colors.textSecondary,
      fontSize: AthenaFontSize.body,
      fontWeight: FontWeight.w400,
    );
    var descriptionText = Text(
      sentinel.description,
      style: descriptionTextStyle,
      textAlign: TextAlign.center,
    );
    // 结构对齐 Codex 的空态：图标 → 大标题 → 说明 → 标签。
    // 实测 Codex 是「48 逻辑图标 + 约 37 逻辑间距 + 约 24 逻辑居中标题」，
    // 标题字号取 24（旧版 28 偏大）。
    var children = [
      _buildGlyph(context, sentinel),
      const SizedBox(height: 28),
      Text(sentinel.name, style: nameTextStyle, textAlign: TextAlign.center),
      if (sentinel.description.isNotEmpty) ...[
        const SizedBox(height: 10),
        descriptionText,
      ],
      const SizedBox(height: 18),
      _TagWrap(sentinel: sentinel),
    ];
    var column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: column,
    );
  }
}

/// 空态顶部图标：Codex 在标题上方放一个约 48 逻辑的标记，
/// 这里用当前 Sentinel 的头像（自定义角色用 emoji，内置角色用应用图标）。
Widget _buildGlyph(BuildContext context, SentinelEntity sentinel) {
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
