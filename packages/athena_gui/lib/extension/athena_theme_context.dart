import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/widgets.dart';

/// 主题取值的统一入口。
///
/// 页面与控件取色一律走 `context.athenaColors`，不直接读 `AthenaTheme`，
/// 也不认识任何设计语言库的 `Theme`。取值点集中在这里，将来换注入方式
/// 只需要改这一个文件。
extension AthenaThemeContext on BuildContext {
  /// 当前色板。
  AthenaColors get athenaColors => AthenaTheme.of(this).colors;

  /// 明确当前是浅色还是深色画布。
  Brightness get athenaBrightness => AthenaTheme.of(this).brightness;

  /// 目标平台。桌面/移动分支用它判定，而不是 `dart:io` 的 `Platform`：
  /// 后者在 widget 测试里恒为宿主平台，移动端分支进不去。
  TargetPlatform get athenaPlatform => AthenaTheme.of(this).platform;
}
