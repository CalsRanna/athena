import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';

/// 测试用主题作用域：从所在 [MaterialApp] 的 [ThemeData] 反推并注入
/// [AthenaTheme]。
///
/// 色板与平台都取自同一个 [ThemeData]，测试里写
/// `theme: buildAthenaThemeData(mode).copyWith(platform: p)` 时，
/// `context.athenaColors` 与 Material 组件看到的是同一套取值，不需要在
/// 每个用例里重复一遍主题表达式。
///
/// 挂在 `MaterialApp.builder` 上：builder 的 child 是 Navigator，
/// 因此所有路由页面与浮层都在作用域内。
class AthenaTestScope extends StatelessWidget {
  const AthenaTestScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = theme.brightness == Brightness.light
        ? AthenaColorMode.light
        : AthenaColorMode.dark;
    return AthenaTheme(
      colors: colorsOf(mode),
      colorMode: mode,
      platform: theme.platform,
      child: child,
    );
  }
}
