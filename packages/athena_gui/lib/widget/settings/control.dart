/// 设置面板里的行内控件：分段控件、下拉。
///
/// 关闭 / 新增用的 ghost 图标按钮是全站通用的 `AthenaGhostIconButton`
/// （`widget/button.dart`）。
///
/// 外壳与分区见 `panel.dart`，行为组件见 `row.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var decoration = BoxDecoration(
      color: colors.neutralRule,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 未选中态不能用 `Colors.transparent`：它的 RGB 是黑，AnimatedContainer
    // 切换档位时会先闪一下半透明深灰（同 menu.dart 的说明）。用目标色的 0
    // 透明度版本，填充与边框全程同色只有 alpha 在动。
    var isSelected = option.value == selected;
    var decoration = BoxDecoration(
      color: isSelected
          ? colors.neutralControlFill
          : colors.neutralControlFill.withValues(alpha: 0),
      border: Border.all(
        color: isSelected
            ? colors.neutralBorder
            : colors.neutralBorder.withValues(alpha: 0),
      ),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var textStyle = TextStyle(
      color: isSelected ? colors.textPrimary : colors.textWeak,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var decoration = BoxDecoration(
      color: colors.neutralControlFill,
      border: Border.all(color: colors.neutralBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: AthenaSettings.controlFontSize,
        height: 1.3,
      ),
    );
    var chevron = Icon(
      HugeIcons.strokeRoundedArrowDown01,
      color: colors.textWeak,
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
