/// 设置面板里的「行」类组件：设置行、段落、状态点。
///
/// 外壳与分区见 `panel.dart`，行内控件见 `control.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 一行设置：左侧标签（+ 徽标 + 说明 + 错误），右侧控件或钻取箭头。
///
/// 实测：标签与说明**同号 14**（大写高都是 10.0），标签半粗近黑、
/// 说明常规灰 `#898781`；行上下内边距 16，行高约 69。
///
/// 行自带 [AthenaSettings.rowInset] 的水平内边距：可点行的 hover / 选中底
/// 因此比文字列宽一圈，而文字仍与分区标题、发丝线对齐。
class AthenaSettingsRow extends StatefulWidget {
  final String label;
  final String? description;

  /// 校验错误：显示在说明下方，`dangerText` 色。
  final String? error;

  /// 标签后面的小徽标（`Built-in` / `Archived` / `Custom`）。
  final String? badge;

  /// 标签左侧的小元素（状态点等），盒 20。
  final Widget? leading;

  /// 右侧控件。
  final Widget? control;

  /// 右端画一个钻取箭头（点进详情的行）。
  final bool chevron;

  /// 列表多选态：底色 `neutralSelected`。
  final bool selected;

  /// 弱化整行（归档项）：标签用次级色。
  final bool dimmed;

  /// 标签最多几行；说明最多几行（null 不限）。
  final int? labelMaxLines;
  final int? descriptionMaxLines;

  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  const AthenaSettingsRow({
    super.key,
    required this.label,
    this.description,
    this.error,
    this.badge,
    this.leading,
    this.control,
    this.chevron = false,
    this.selected = false,
    this.dimmed = false,
    this.labelMaxLines,
    this.descriptionMaxLines,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<AthenaSettingsRow> createState() => _AthenaSettingsRowState();
}

class _AthenaSettingsRowState extends State<AthenaSettingsRow> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var hasDescription = widget.description != null;
    var labelStyle = TextStyle(
      color: widget.dimmed ? colors.textSecondary : colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: AthenaSettings.rowLabelWeight,
      height: 1.4,
    );
    var descriptionStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: FontWeight.w400,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var errorStyle = TextStyle(
      color: colors.dangerText,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var label = Text(
      widget.label,
      maxLines: widget.labelMaxLines,
      overflow: widget.labelMaxLines == null ? null : TextOverflow.ellipsis,
      style: labelStyle,
    );
    var labelRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: Center(child: widget.leading),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: label),
        if (widget.badge != null) ...[
          const SizedBox(width: 8),
          AthenaSettingsBadge(text: widget.badge!),
        ],
      ],
    );
    // 有 leading 时说明与标签的文字左缘对齐（跳过 leading 的 30）。
    var textIndent = widget.leading == null ? 0.0 : 30.0;
    var labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelRow,
        if (hasDescription) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (hasDescription)
          Padding(
            padding: EdgeInsets.only(left: textIndent),
            child: Text(
              widget.description!,
              maxLines: widget.descriptionMaxLines,
              overflow: widget.descriptionMaxLines == null
                  ? null
                  : TextOverflow.ellipsis,
              style: descriptionStyle,
            ),
          ),
        if (widget.error != null) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (widget.error != null)
          Padding(
            padding: EdgeInsets.only(left: textIndent),
            child: Text(widget.error!, style: errorStyle),
          ),
      ],
    );
    var trailing = widget.control;
    if (trailing == null && widget.chevron) {
      trailing = Icon(
        LucideIcons.chevronRight,
        color: colors.iconSecondary,
        size: 14,
      );
    }
    var row = Row(
      crossAxisAlignment: hasDescription && widget.control != null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: labelColumn),
        if (trailing != null) const SizedBox(width: 24),
        if (trailing != null) trailing,
      ],
    );
    var content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.rowInset,
        vertical: AthenaSettings.rowPaddingVertical,
      ),
      child: row,
    );
    var interactive = widget.onTap != null || widget.onSecondaryTap != null;
    if (!interactive && !widget.selected) return content;
    // 静止态用目标色的 0 透明度版；透明黑插值会先闪深色（见 menu.dart）
    var background = widget.selected
        ? colors.neutralSelected
        : hover && interactive
        ? colors.neutralRule
        : colors.neutralRule.withValues(alpha: 0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AthenaSettings.navRowRadius),
          ),
          child: content,
        ),
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
    var textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.6,
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
