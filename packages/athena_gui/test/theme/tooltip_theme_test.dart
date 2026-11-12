import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全站提示框的材质由 `buildAthenaThemeData` 的 `tooltipTheme` 统一提供：
/// 反色面 `surfaceRaised` 配 `textOnRaised` 的 caption 文案。
///
/// 调用点只负责 `message` 与定位参数（`preferBelow` / `constraints`）；
/// 谁再手写 `decoration` / `textStyle`，全站样式就会从这里漂移出去。
void main() {
  for (final (mode, colors) in [
    (AthenaColorMode.light, AthenaColors.light),
    (AthenaColorMode.dark, AthenaColors.dark),
  ]) {
    test('${mode.name} tooltipTheme 使用反色面与 caption 文案', () {
      final tooltipTheme = AthenaMaterialTheme.buildAthenaThemeData(mode)
          .tooltipTheme;

      expect(
        tooltipTheme.decoration,
        BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AthenaRadius.control),
        ),
      );
      expect(
        tooltipTheme.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      );
      expect(
        tooltipTheme.textStyle?.fontSize,
        AthenaTextStyle.caption.fontSize,
      );
      expect(tooltipTheme.textStyle?.color, colors.textOnRaised);
    });
  }
}
