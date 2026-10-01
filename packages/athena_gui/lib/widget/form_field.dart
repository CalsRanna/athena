import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:flutter/material.dart';

/// 移动端表单的一个字段：标签 → 控件 →（可选）说明 / 校验错误。
///
/// 这是 [AthenaSettingsRow] 的**纵向版本**：设置面板的行是「左标签 + 右控件」的
/// 横向布局、绑在 36 高的桌面控件尺度上；移动端是整页表单，标签在上、控件在下。
/// 两者**不共用实现**——把桌面的行几何带进移动端会得到一列挤在一起的控件。
///
/// 抽它是因为移动端 7 个表单页各自手写了同一段序列（`label` → `SizedBox(12)`
/// → 控件 → 说明），间距靠人记。这里把间距固定下来：
///
/// ```
/// 标签            16 / 24 / w600（AthenaFormTileLabel.large）
///   ↕ 12
/// 控件            调用方给，通常是 AthenaInput
///   ↕ 4（紧凑）或 8（宽松，descriptionGap）
/// 说明 / 错误      caption 12 / textSecondary；错误用 dangerText
/// ```
///
/// 字段之间的间距（16 / 20 / 32）由调用方在列表里写 `SizedBox`——它不是字段
/// 内部的一部分，各页按分区节奏取值。
class AthenaFormField extends StatelessWidget {
  /// 字段标签。
  final String label;

  /// 输入控件，通常是 `AthenaInput`。
  final Widget control;

  /// 说明文字，可选。与 [error] 同时给出时只显示 [error]。
  final String? description;

  /// 校验错误，可选：`caption` + `dangerText`，排在控件下方。
  final String? error;

  /// 标签右侧的附加控件（如"生成"按钮），与
  /// [AthenaFormTileLabel.large] 的 `trailing` 同义。
  final Widget? trailing;

  /// 控件与说明之间的间距。默认 4（多数页面用紧凑档）；`agent_page` 那种
  /// 说明较长的用 8。
  final double descriptionGap;

  const AthenaFormField({
    super.key,
    required this.label,
    required this.control,
    this.description,
    this.error,
    this.trailing,
    this.descriptionGap = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final note = error ?? description;
    final noteStyle = AthenaTextStyle.caption.copyWith(
      color: error != null ? colors.dangerText : colors.textSecondary,
    );
    final children = [
      AthenaFormTileLabel.large(title: label, trailing: trailing),
      const SizedBox(height: 12),
      control,
      if (note != null) ...[
        SizedBox(height: descriptionGap),
        Text(note, style: noteStyle),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
