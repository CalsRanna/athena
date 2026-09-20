/// 设置面板里的行内控件：分段控件、下拉、ghost 图标按钮。
///
/// 外壳与分区见 `panel.dart`，行为组件见 `row.dart`。
library;

import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 分段控件（Claude 的 segmented control）。
///
/// 实测：轨道 `#F3F3F3` 无描边、高 32、圆角 8；选中块是**纯白填充 +
/// 1px `#E7E7E7` 描边**并**铺满轨道高**（不是内缩的小块）；
/// 选中文字 12 半粗近黑，未选中 12 常规灰 `#898781`。
class AthenaSettingsSegmented<T> extends StatelessWidget {
  final List<AthenaSegmentOption<T>> options;
  final T selected;
  final void Function(T value)? onChanged;
  const AthenaSettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.controlTrack,
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var children = [
      for (final option in options) _buildSegment(context, option),
    ];
    return Container(
      height: AthenaSettings.controlHeight,
      decoration: decoration,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSegment(BuildContext context, AthenaSegmentOption<T> option) {
    final settings = settingsColorsOf(context);
    var isSelected = option.value == selected;
    var decoration = BoxDecoration(
      color: isSelected ? settings.controlFill : Colors.transparent,
      border: isSelected
          ? Border.all(color: settings.controlBorder)
          : Border.all(color: Colors.transparent),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var textStyle = TextStyle(
      color: isSelected ? settings.navSelectedText : settings.navMuted,
      fontSize: AthenaSettings.segmentFontSize,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    );
    var segment = AnimatedContainer(
      alignment: Alignment.center,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(option.label, style: textStyle, maxLines: 1),
    );
    if (onChanged == null) return segment;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged?.call(option.value),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: segment),
    );
  }
}

/// 分段控件的一个选项。
class AthenaSegmentOption<T> {
  final T value;
  final String label;
  const AthenaSegmentOption({required this.value, required this.label});
}

/// 设置里的下拉选择（Claude 的 select 控件）。
///
/// 实测：白底、1px `#E7E7E7` 描边、高 32、圆角 8、文字 14 近黑，
/// 右端一个 chevron。它只管外观，点开的是调用方给的弹层。
class AthenaSettingsSelect extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const AthenaSettingsSelect({super.key, required this.label, this.onTap});

  @override
  State<AthenaSettingsSelect> createState() => _AthenaSettingsSelectState();
}

class _AthenaSettingsSelectState extends State<AthenaSettingsSelect> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.controlFill,
      border: Border.all(color: settings.controlBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: settings.navSelectedText,
        fontSize: AthenaSettings.controlFontSize,
        height: 1.3,
      ),
    );
    var chevron = Icon(
      HugeIcons.strokeRoundedArrowDown01,
      color: settings.navMuted,
      size: 14,
    );
    var content = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.controlPaddingHorizontal,
      ),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          chevron,
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: content,
      ),
    );
  }
}

/// 设置面板里的 ghost 图标按钮（关闭、新增）。
///
/// Claude 的控件语言：静止无底色，hover 填充前景色 5%，圆角 7。
class AthenaSettingsIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double box;
  final double iconSize;
  const AthenaSettingsIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.box = 28,
    this.iconSize = AthenaSettings.closeIconSize,
  });

  @override
  State<AthenaSettingsIconButton> createState() =>
      _AthenaSettingsIconButtonState();
}

class _AthenaSettingsIconButtonState extends State<AthenaSettingsIconButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var icon = Icon(
      widget.icon,
      color: settings.navText,
      size: widget.iconSize,
    );
    var container = AnimatedContainer(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hover ? settings.rule : Colors.transparent,
        borderRadius: BorderRadius.circular(AthenaRadius.row),
      ),
      duration: const Duration(milliseconds: 120),
      height: widget.box,
      width: widget.box,
      child: icon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
