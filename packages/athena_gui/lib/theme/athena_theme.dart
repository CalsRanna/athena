import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 外观模式；与 `ThemeMode` 同名同序，持久化按 [name] 存字符串。
enum AthenaThemeMode { light, dark, system }

/// 把 [AthenaThemeMode] 解析成具体色板（system 按平台亮度）。
AthenaColorMode resolveColorMode(AthenaThemeMode mode) {
  return switch (mode) {
    AthenaThemeMode.light => AthenaColorMode.light,
    AthenaThemeMode.dark => AthenaColorMode.dark,
    AthenaThemeMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.light
          ? AthenaColorMode.light
          : AthenaColorMode.dark,
  };
}

/// 按色板模式取语义色。
AthenaColors colorsOf(AthenaColorMode mode) =>
    mode == AthenaColorMode.light ? AthenaColors.light : AthenaColors.dark;

/// 主题作用域：向子树提供色板、外观模式与目标平台。
///
/// 取值入口是 `context.athenaColors`（见 `extension/athena_theme_context.dart`）。
/// 页面与控件只依赖本类，不认识任何设计语言库。
class AthenaTheme extends InheritedWidget {
  const AthenaTheme({
    super.key,
    required this.colors,
    required this.colorMode,
    required this.platform,
    required super.child,
  });

  final AthenaColors colors;
  final AthenaColorMode colorMode;
  final TargetPlatform platform;

  /// 当前外观模式对应的亮度。
  Brightness get brightness =>
      colorMode == AthenaColorMode.light ? Brightness.light : Brightness.dark;

  /// 取作用域。debug 下找不到祖先直接断言失败——静默回退到浅色会让
  /// 漏装的页面照常渲染，深色主题下只是「颜色不对」，很难查。release 下
  /// 回退浅色，避免一个浮层把整页拖崩。
  static AthenaTheme of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AthenaTheme>();
    assert(
      theme != null,
      'AthenaTheme 未安装：页面与控件的取色都要求它是祖先。'
      '应用根在 main.dart 注入，测试用 athenaTestApp 包裹。',
    );
    return theme ??
        const AthenaTheme(
          colors: AthenaColors.light,
          colorMode: AthenaColorMode.light,
          platform: TargetPlatform.linux,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(AthenaTheme oldWidget) =>
      colors != oldWidget.colors ||
      colorMode != oldWidget.colorMode ||
      platform != oldWidget.platform;
}
