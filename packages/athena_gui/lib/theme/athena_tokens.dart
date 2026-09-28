/// Athena 的设计 token：几何、排版、字体族、阴影。
///
/// 与 [AthenaColors] 的分工：`athena_colors.dart` 管颜色（挂 ThemeExtension，
/// 随主题切换），本文件管不随主题变化的常量。
///
/// 视觉语言来自 **Claude 桌面端**（取值来自它 `app.asar` 里的 `--cds-*` 变量，
/// 并与窗口截图采样交叉验证）：
/// - UI 与正文用**系统字体**，等宽只用于代码块 / 终端 / 技术标签；
/// - 圆角克制：行 / 控件 7、卡片 10、对话框 / 菜单 12；筛选 chip 是胶囊；
/// - 层级靠"提亮一档的灰底 + 极淡的分隔线"，浮层带一层柔阴影；
/// - 画布是暖白（浅色）/ 近黑（深色），**不使用纯黑**。
library;

import 'package:flutter/material.dart';

/// 圆角等级。取值来自 **Claude 桌面端的 `--cds-radius-*`**。
///
/// Claude 的圆角很克制：最小档 5、控件档 7、composer 也只有 12。
/// 没有 20/24 这种大圆角。
///
/// | Claude 变量 | 值 | 本仓 token | 组件 |
/// |---|---|---|---|
/// | `--cds-radius` | 4 | `xs` | 极小元素 |
/// | `--cds-radius--sm` / `--xs` | 5 | `inline` | 徽标、行内代码、勾选框 |
/// | `--cds-radius--lg` | 7 | `row` / `control` | 列表行、按钮、输入框 |
/// | （卡片/面板） | 10 | `container` | 卡片、代码块 |
/// | （对话框/菜单） | 12 | `panel` / `menu` | 对话框、弹出菜单 |
/// | `--cds-radius-composer` | 12 | `composer` | composer |
/// | `--radius-full` | 9999 | `pill` | chip、发送按钮、头像 |
abstract final class AthenaRadius {
  static const xs = 4.0;
  static const inline = 5.0;
  static const row = 7.0;
  static const control = 7.0;
  static const container = 10.0;
  static const panel = 12.0;
  static const menu = 12.0;
  static const composer = 12.0;
  static const pill = 999.0;
}

/// 间距等级。
abstract final class AthenaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// 桌面左侧栏宽度。Claude 实测：侧栏与画布的分界线在逻辑 287，即宽 288。
  static const sidebar = 288.0;
}

/// 以 Medium 正文 14 / 22 为基准的四级字号。
///
/// 辅助文字 12 / 18、常规 UI 14 / 22、标题 16 / 24、空态标题 20 / 28。
/// 角色可以共用字号，通过字重区分；会话三档仅由 [AthenaTextSize] 提供。
abstract final class AthenaFontSize {
  /// 空态标题。
  static const hero = 20.0;

  /// 页、对话框与设置分区标题。
  static const title = 16.0;

  /// 卡片、列表项与表单标签的强调文字，与常规 UI 同号。
  static const section = body;

  /// 菜单条目、选择器行与设置行。
  static const row = body;

  /// 消息正文（Markdown）的默认 Medium 档，行盒 22。
  static const prose = body;

  /// 常规 UI、输入框与侧栏行的共同基准，不随会话档位改变。
  static const body = 14.0;

  /// 默认消息行盒 22，换算成 Flutter 的 `TextStyle.height`。
  static const proseHeight = bodyHeight;

  static const heroHeight = 28.0 / hero;
  static const titleHeight = 24.0 / title;
  static const bodyHeight = 22.0 / body;
  static const captionHeight = 18.0 / caption;

  /// 按钮、选择器与可操作标签，与常规 UI 同号。
  static const label = body;

  /// 辅助说明、元信息与分组标签。
  static const caption = 12.0;

  /// 技术标签的默认等宽字号；会话代码使用 [AthenaTextSize.code]。
  static const mono = 12.0;
}

/// 文字样式预设：一个角色 = 字号 + 默认字重（+ 行盒）。
///
/// 调用方只需补颜色：`AthenaTextStyle.section.copyWith(color: colors.textPrimary)`；
/// 字重与预设不同时再覆盖 `fontWeight`。角色与字号的对应见 [AthenaFontSize]，
/// 设计口径见 DESIGN.md §3。
///
/// 每个预设都携带所属层级的行盒，组件不再各自覆盖比例行高。
///
/// 等宽不在这里：代码 / 工具参数 / 输出走 [athenaMono]。
abstract final class AthenaTextStyle {
  /// 空态欢迎大标题：20 / 28 / w600。
  static const hero = TextStyle(
    fontSize: AthenaFontSize.hero,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.heroHeight,
  );

  /// 页 / 对话框 / 设置分区标题：16 / 24 / w600。
  static const title = TextStyle(
    fontSize: AthenaFontSize.title,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.titleHeight,
  );

  /// 卡片标题、列表项标题与表单标签：14 / 22 / w600。
  static const section = TextStyle(
    fontSize: AthenaFontSize.section,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.bodyHeight,
  );

  /// 菜单条目、选择器行、设置行：14 / w400。
  static const row = TextStyle(
    fontSize: AthenaFontSize.row,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.bodyHeight,
  );

  /// 消息正文（Markdown）：默认 14 / w400，行盒 22。
  static const prose = TextStyle(
    fontSize: AthenaFontSize.prose,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.proseHeight,
  );

  /// UI 正文、输入框、侧栏行：14 / 22 / w400。
  static const body = TextStyle(
    fontSize: AthenaFontSize.body,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.bodyHeight,
  );

  /// 按钮、选择器与可操作标签：14 / 22 / w500。
  static const label = TextStyle(
    fontSize: AthenaFontSize.label,
    fontWeight: FontWeight.w500,
    height: AthenaFontSize.bodyHeight,
  );

  /// 辅助说明、元信息、分组标题：12 / 18 / w400。
  static const caption = TextStyle(
    fontSize: AthenaFontSize.caption,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.captionHeight,
  );
}

/// 会话消息字号档位（设置里的「Text size」）。
///
/// `AthenaWorkspaceTextSize` 只在消息列表内提供正文与代码共用的固定排版；
/// composer、placeholder、侧栏、顶栏、设置与菜单均不受档位影响。
/// 各档使用逻辑像素，不替换系统无障碍 `TextScaler`。
enum AthenaTextSize {
  small('Small', 13.0, 20.0),
  medium('Medium', AthenaFontSize.prose, 22.0),
  large('Large', 15.0, 24.0);

  /// 分段控件上的显示名。
  final String label;

  /// 消息正文与代码的固定字号（逻辑像素）。
  final double fontSize;

  /// 消息正文与代码的固定行盒（系统无障碍缩放前）。
  final double lineHeight;

  const AthenaTextSize(this.label, this.fontSize, this.lineHeight);

  TextStyle get prose => AthenaTextStyle.prose.copyWith(
    fontSize: fontSize,
    height: lineHeight / fontSize,
  );

  TextStyle get code => athenaMono(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    height: lineHeight / fontSize,
  );
}

/// 字体族。
///
/// **UI 与正文走系统字体**（`null` = 平台默认：macOS SF Pro / Windows Segoe UI）——
/// Claude 的侧栏、设置、按钮、正文都是比例字体，等宽只有代码与终端在用。
/// 早期实现把整个 UI 做成等宽，是对 Claude 的误读。
abstract final class AthenaFont {
  /// UI 与正文：交给平台默认字体（含 CJK 回退）。
  static const String? ui = null;

  /// 手动指定时的回退链（仅当需要显式覆盖平台字体时使用）。
  static const uiFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
  ];

  /// 代码与终端：等宽。
  static const mono = 'Menlo';

  static const monoFallback = <String>[
    'SF Mono',
    'Consolas',
    'Cascadia Mono',
    'DejaVu Sans Mono',
    'monospace',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
  ];
}

/// 浮起容器的柔阴影。
///
/// Claude 的对话框与弹出层不是硬 1px 描边，而是一圈非常柔和的投影；
/// 移动端 composer 用 [raised]，对话框与菜单用 [overlay]。
abstract final class AthenaShadow {
  /// 低浮起：composer、行内浮层。
  static List<BoxShadow> raised(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// 高浮起：对话框、弹出菜单。
  static List<BoxShadow> overlay(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

/// 统一的等宽文字样式入口。
///
/// 只有代码 / 工具 / 技术标签用它；正文与 UI 一律不传 fontFamily，
/// 走主题里的系统字体。
TextStyle athenaMono({
  Color? color,
  double fontSize = AthenaFontSize.mono,
  FontWeight? fontWeight,
  double? height = AthenaFontSize.captionHeight,
}) {
  return TextStyle(
    color: color,
    fontFamily: AthenaFont.mono,
    fontFamilyFallback: AthenaFont.monoFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}
