/// 设置面板里的「行」类组件：设置行、只读值行、条目列表与空态。
///
/// 外壳与分区见 `panel.dart`，行内控件见 `control.dart`。
library;

import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 一行设置：左侧标签（+ 说明），右侧控件，上下各 16 内边距。
///
/// 实测：标签与说明**同号 14**（大写高都是 10.0），标签半粗近黑、
/// 说明常规灰 `#898781`；行上下内边距 16，行高约 69。
class AthenaSettingsRow extends StatefulWidget {
  final String label;
  final String? description;
  final Widget? control;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  const AthenaSettingsRow({
    super.key,
    required this.label,
    this.description,
    this.control,
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
    final settings = settingsColorsOf(context);
    var hasDescription = widget.description != null;
    var labelStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: AthenaSettings.rowLabelWeight,
      height: 1.4,
    );
    var descriptionStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: FontWeight.w400,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: labelStyle),
        if (hasDescription) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (hasDescription)
          Text(widget.description!, style: descriptionStyle),
      ],
    );
    var row = Row(
      crossAxisAlignment: hasDescription
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: labelColumn),
        if (widget.control != null) const SizedBox(width: 24),
        if (widget.control != null) widget.control!,
      ],
    );
    var content = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AthenaSettings.rowPaddingVertical,
      ),
      child: row,
    );
    if (widget.onTap == null && widget.onSecondaryTap == null) return content;
    // 可点行的 hover 底用设置面板的中性灰（Claude 的侧栏 hover 是暖灰，
    // 白底上会偏黄，这里沿用面板自己的中性灰）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: hover ? settings.rule : Colors.transparent,
            borderRadius: BorderRadius.circular(AthenaRadius.row),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AthenaSettings.rowPaddingVertical,
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// 只读的「标签 / 值」行，用于经验详情这类没有控件的元信息。
class AthenaSettingsValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  const AthenaSettingsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 96,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var labelStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    var valueStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    var children = [
      SizedBox(width: labelWidth, child: Text(label, style: labelStyle)),
      Expanded(child: Text(value, style: valueStyle)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: children),
    );
  }
}

/// 列表行：用于设置页里的条目列表（Provider / Sentinel / Skill / Experience）。
///
/// 它是**内容列表**不是导航：白底、行间 1px 发丝线、没有圆角块。
/// 选中底 `#E3E3E2`，hover 底 `#F3F3F3`。
class AthenaSettingsListItem extends StatefulWidget {
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  const AthenaSettingsListItem({
    super.key,
    required this.label,
    this.selected = false,
    this.trailing,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<AthenaSettingsListItem> createState() => _AthenaSettingsListItemState();
}

class _AthenaSettingsListItemState extends State<AthenaSettingsListItem> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var contentColor = widget.selected
        ? settings.navSelectedText
        : settings.navText;
    var background = widget.selected
        ? settings.navSelected
        : hover
        ? settings.rule
        : settings.rule.withValues(alpha: 0);
    var textStyle = TextStyle(
      color: contentColor,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: settings.rule)),
      ),
      duration: const Duration(milliseconds: 120),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: container,
      ),
    );
  }
}

/// 设置页里的条目列表列（Provider / Sentinel / Skill / Experience）。
///
/// 它**不是导航**：底色与内容区同为纯白，靠右侧 1px `#E4E4E3` 分界，
/// 行与行之间是 1px 发丝线，没有圆角选中块。
class AthenaSettingsListColumn extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final List<Widget> children;
  final Widget? footer;

  /// 与右键菜单的偏移约定保持一致（`Offset(240, 50)`）。
  final double width;
  const AthenaSettingsListColumn({
    super.key,
    required this.title,
    required this.children,
    this.onAdd,
    this.footer,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var titleStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.navGroupFontSize,
      height: 1.3,
    );
    var header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: titleStyle)),
          if (onAdd != null)
            AthenaSettingsIconButton(
              box: 24,
              icon: HugeIcons.strokeRoundedAdd01,
              iconSize: 14,
              onTap: onAdd,
            ),
        ],
      ),
    );
    var decoration = BoxDecoration(
      border: Border(right: BorderSide(color: settings.navDivider)),
    );
    var children2 = [
      header,
      Expanded(child: ListView(padding: EdgeInsets.zero, children: children)),
      if (footer != null) footer!,
    ];
    return Container(
      width: width,
      decoration: decoration,
      child: Column(children: children2),
    );
  }
}

/// 空态文字（No Skills / No Sentinels ...）。
class AthenaSettingsEmptyState extends StatelessWidget {
  final String text;
  const AthenaSettingsEmptyState({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var textStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text(text, style: textStyle)),
    );
  }
}
