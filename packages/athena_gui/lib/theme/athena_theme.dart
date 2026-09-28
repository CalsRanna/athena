import 'dart:ui';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 把 [ThemeMode] 解析成具体色板（system 按平台亮度）。
AthenaColorMode resolveColorMode(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => AthenaColorMode.light,
    ThemeMode.dark => AthenaColorMode.dark,
    ThemeMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.light
          ? AthenaColorMode.light
          : AthenaColorMode.dark,
  };
}

/// 按色板模式取语义色。
AthenaColors colorsOf(AthenaColorMode mode) =>
    mode == AthenaColorMode.light ? AthenaColors.light : AthenaColors.dark;

/// 构建指定模式下的 [ThemeData]。
///
/// **字体**：UI 与正文走系统字体（[AthenaFont.ui] 为 `null`，用平台默认），
/// 只有代码 / 工具 / 技术标签显式走 [athenaMono]。侧栏、设置、
/// 按钮、正文都是比例字体——把整个 UI 做成等宽是对它的误读。
///
/// **强调色**：[AthenaColors.accent] 挂到 `ColorScheme.primary`，
/// 让 Material 组件的强调与青瓷主操作一致，前景同步使用配套的 textOnAccent。
ThemeData buildAthenaThemeData(AthenaColorMode mode) {
  final colors = colorsOf(mode);
  final isLight = mode == AthenaColorMode.light;
  final base = isLight ? const ColorScheme.light() : const ColorScheme.dark();
  return ThemeData(
    colorScheme: base.copyWith(
      primary: colors.accent,
      onPrimary: colors.textOnAccent,
      secondary: colors.accent,
      onSecondary: colors.textOnAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.statusError,
    ),
    fontFamily: AthenaFont.ui,
    fontFamilyFallback: AthenaFont.uiFallback,
    textTheme: const TextTheme(
      displayLarge: AthenaTextStyle.hero,
      displayMedium: AthenaTextStyle.hero,
      displaySmall: AthenaTextStyle.hero,
      headlineLarge: AthenaTextStyle.title,
      headlineMedium: AthenaTextStyle.title,
      headlineSmall: AthenaTextStyle.title,
      titleLarge: AthenaTextStyle.title,
      titleMedium: AthenaTextStyle.section,
      titleSmall: AthenaTextStyle.section,
      bodyLarge: AthenaTextStyle.body,
      bodyMedium: AthenaTextStyle.body,
      bodySmall: AthenaTextStyle.caption,
      labelLarge: AthenaTextStyle.label,
      labelMedium: AthenaTextStyle.label,
      labelSmall: AthenaTextStyle.caption,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AthenaRadius.panel)),
      ),
    ),
    scaffoldBackgroundColor: colors.surface,
    dividerColor: colors.divider,
    splashFactory: NoSplash.splashFactory,
    useMaterial3: true,
    extensions: [colors],
  );
}
