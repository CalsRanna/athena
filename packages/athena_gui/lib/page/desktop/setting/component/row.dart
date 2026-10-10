/// 设置面板里的「行」类组件：设置行、列表行、外链行，以及段落与状态点。
///
/// 三行按用途分开：设置行是「左标签 + 右控件」的静态行；列表行整行可点、
/// 可选、右端带钻取箭头（Provider / Sentinel / Skill / Experience 列表）；
/// 外链行整行可点、跳往站外（About 的资源链接）。三者共用一个私有的
/// [_SettingsRowLabel] 组织标签、说明与徽标，可点行再套 [_InteractiveRowShell]。
///
/// 外壳与分区见 `panel.dart`，行内控件见 `control.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:flutter/material.dart';

/// 设置行：左侧标签（+ 徽标 + 说明 + 错误），右侧控件。
///
/// 标签与说明同号 14，两者都是常规字重：标签 `textPrimary`、说明 `textSecondary`；
/// 行上下内边距 16，行高约 69。
class AthenaSettingsRow extends StatelessWidget {
  final String label;
  final String? description;

  /// 校验错误：显示在说明下方，`dangerText` 色。
  final String? error;

  /// 标签后面的小徽标（`Custom` 等）。
  final String? badge;

  /// 右侧控件。
  final Widget? control;

  /// 说明最多几行（null 不限）。
  final int? descriptionMaxLines;

  const AthenaSettingsRow({
    super.key,
    required this.label,
    this.description,
    this.error,
    this.badge,
    this.control,
    this.descriptionMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final labelColumn = _SettingsRowLabel(
      label: label,
      description: description,
      error: error,
      badge: badge,
      descriptionMaxLines: descriptionMaxLines,
    );
    final row = Row(
      crossAxisAlignment: description != null && control != null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: labelColumn),
        if (control != null) const SizedBox(width: 24),
        if (control != null) control!,
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.rowInset,
        vertical: AthenaSettings.rowPaddingVertical,
      ),
      child: row,
    );
  }
}

/// 列表行：整行可点，右端一个钻取箭头；支持多选底与归档弱化。
///
/// 用于 Provider / Sentinel / Skill / Experience 的列表：普通点击钻取详情，
/// ⌘ / ⇧ 多选时底色 `neutralSelected`，右键由调用方接 [onSecondaryTap]。
///
/// 行自带 [AthenaSettings.rowInset] 的水平内边距：hover / 选中底因此比文字列
/// 宽一圈，而文字仍与分区标题、发丝线对齐。
class AthenaSettingsListRow extends StatelessWidget {
  final String label;
  final String? description;

  /// 标签后面的小徽标（`Built-in` / `Custom`）。
  final String? badge;

  /// 标签左侧的小元素（状态点等），盒 20。
  final Widget? leading;

  /// 多选态：底色 `neutralSelected`。
  final bool selected;

  /// 弱化整行（归档项）：标签用次级色。
  final bool dimmed;

  /// 标签最多几行；说明最多几行（null 不限）。
  final int? labelMaxLines;
  final int? descriptionMaxLines;

  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;

  const AthenaSettingsListRow({
    super.key,
    required this.label,
    this.description,
    this.badge,
    this.leading,
    this.selected = false,
    this.dimmed = false,
    this.labelMaxLines,
    this.descriptionMaxLines,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return _InteractiveRowShell(
      selected: selected,
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AthenaSettings.rowInset,
          vertical: AthenaSettings.rowPaddingVertical,
        ),
        child: Row(
          children: [
            Expanded(
              child: _SettingsRowLabel(
                label: label,
                description: description,
                badge: badge,
                leading: leading,
                dimmed: dimmed,
                labelMaxLines: labelMaxLines,
                descriptionMaxLines: descriptionMaxLines,
              ),
            ),
            const SizedBox(width: 24),
            Icon(
              AthenaIcons.forward,
              color: colors.iconSecondary,
              size: AthenaIcon.inlineSize,
            ),
          ],
        ),
      ),
    );
  }
}

/// 外链行：整行可点，跳往站外（About 的仓库、反馈、许可）。
///
/// 与列表行同一套 hover 反馈；不参与多选，也没有选中态与徽标。
class AthenaSettingsLinkRow extends StatelessWidget {
  final String label;
  final String? description;
  final int? descriptionMaxLines;
  final VoidCallback? onTap;

  const AthenaSettingsLinkRow({
    super.key,
    required this.label,
    this.description,
    this.descriptionMaxLines,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return _InteractiveRowShell(
      selected: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AthenaSettings.rowInset,
          vertical: AthenaSettings.rowPaddingVertical,
        ),
        child: Row(
          children: [
            Expanded(
              child: _SettingsRowLabel(
                label: label,
                description: description,
                descriptionMaxLines: descriptionMaxLines,
              ),
            ),
            const SizedBox(width: 24),
            Icon(
              AthenaIcons.forward,
              color: colors.iconSecondary,
              size: AthenaIcon.inlineSize,
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置行与列表行共用的标签区：标签（+ 可选 leading + 可选徽标）+ 说明 + 错误。
///
/// 三者同号 14：标签 `textPrimary`、说明 `textSecondary`、错误 `dangerText`；
/// 有 leading 时说明与错误左缘跳过 leading 的宽度（30），与标签文字对齐。
class _SettingsRowLabel extends StatelessWidget {
  final String label;
  final String? description;
  final String? error;
  final String? badge;
  final Widget? leading;
  final bool dimmed;
  final int? labelMaxLines;
  final int? descriptionMaxLines;

  const _SettingsRowLabel({
    required this.label,
    this.description,
    this.error,
    this.badge,
    this.leading,
    this.dimmed = false,
    this.labelMaxLines,
    this.descriptionMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final hasDescription = description != null;
    final labelStyle = TextStyle(
      color: dimmed ? colors.textSecondary : colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: FontWeight.w400,
      height: AthenaFontSize.bodyHeight,
    );
    final descriptionStyle = TextStyle(
      color: colors.textSecondary,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: FontWeight.w400,
      height: AthenaSettings.rowDescriptionHeight,
    );
    final errorStyle = TextStyle(
      color: colors.dangerText,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaSettings.rowDescriptionHeight,
    );
    final labelText = Text(
      label,
      maxLines: labelMaxLines,
      overflow: labelMaxLines == null ? null : TextOverflow.ellipsis,
      style: labelStyle,
    );
    final labelRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          SizedBox(width: 20, height: 20, child: Center(child: leading)),
          const SizedBox(width: 10),
        ],
        Flexible(child: labelText),
        if (badge != null) ...[
          const SizedBox(width: 8),
          AthenaSettingsBadge(text: badge!),
        ],
      ],
    );
    final textIndent = leading == null ? 0.0 : 30.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelRow,
        if (hasDescription) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (hasDescription)
          Padding(
            padding: EdgeInsets.only(left: textIndent),
            child: Text(
              description!,
              maxLines: descriptionMaxLines,
              overflow: descriptionMaxLines == null
                  ? null
                  : TextOverflow.ellipsis,
              style: descriptionStyle,
            ),
          ),
        if (error != null) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(left: textIndent),
            child: Text(error!, style: errorStyle),
          ),
      ],
    );
  }
}

/// 可点行（列表行 / 外链行）共用的外壳：hover / 选中底色、圆角与手势。
///
/// 两种行的交互一致，只有标签区与尾部不同，因此把这段抽出来共用。
class _InteractiveRowShell extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;

  const _InteractiveRowShell({
    required this.child,
    required this.selected,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final interactive = onTap != null || onSecondaryTap != null;
    if (!interactive && !selected) return child;
    return AthenaHover(
      enabled: interactive,
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      builder: (context, hover) => AnimatedContainer(
        duration: AthenaMotion.hover,
        decoration: BoxDecoration(
          // 静止态用目标色的 0 透明度版；透明黑插值会先闪深色
          color: selected
              ? colors.neutralSelected
              : hover && interactive
              ? colors.neutralRule
              : colors.neutralRule.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AthenaSettings.navRowRadius),
        ),
        child: child,
      ),
    );
  }
}

/// 只读的一段正文（经验的 Lesson / Context），对齐文字列。
class AthenaSettingsParagraph extends StatelessWidget {
  final String text;
  const AthenaSettingsParagraph({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaFontSize.bodyHeight,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.rowInset,
        vertical: AthenaSettings.rowLabelGap,
      ),
      child: SelectableText(text, style: textStyle),
    );
  }
}

/// 行首的状态点（直径 6）：启用 / 停用之类的二元状态。
class AthenaSettingsDot extends StatelessWidget {
  final Color color;
  const AthenaSettingsDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
