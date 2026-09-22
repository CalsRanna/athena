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

/// 字号等级。取值来自 **Claude 桌面端 `.cds-root` 的 `--cds-font-size-*`**。
///
/// 该变量的默认档（未叠加 `data-density` / `data-text-size`）是
/// caption 12 / body 14 / prose 15 / heading 14；本仓的 [body] 与 [prose]
/// 取的是文字档 small 解析后的值（`--textsm` = 13，见各自注释里的实测
/// 交叉验证），标题、标签、说明仍按默认档。
abstract final class AthenaFontSize {
  /// 空态标题。
  static const hero = 22.0;

  /// 页 / 对话框标题（`--cds-font-size-heading--textlg` = 15）。
  static const title = 15.0;

  /// 分区标题、卡片标题（`--cds-font-size-heading` = 14）。
  static const section = 14.0;

  /// 菜单条目、选择器行、设置行（Claude 默认档 body = 14）。
  ///
  /// 与 [section] 同号但不同角色：[section] 是加粗的标题，这里是常规字重的
  /// 行文字。本仓的 [body] 取的是文字档 small 的 13，而 Claude 的菜单与
  /// 设置行实测仍是 14，所以单独留一个名字，免得写成 `section` + w400。
  static const row = 14.0;

  /// **消息正文（Markdown）**：文字档 small 下取
  /// `--cds-font-size-prose--textsm` = 13，行高 `--cds-leading-prose` = 20。
  ///
  /// 与 UI 正文同号。实测交叉验证：Claude 窗口里
  /// 「解压完成，我来检查并定位 Claude 的真实 CSS。」(16 全角 + 9 西文)
  /// 总宽 276.5 逻辑像素 → 反推 13.0；按 15 算会得到 319，对不上。
  static const prose = 13.0;

  /// 正文、输入框、列表行（`--cds-font-size-body`）。
  ///
  /// 取按文字档 small 解析后的值：`--cds-font-size-body--textsm` = 13，
  /// 行高 `--cds-leading-body` = 19。与消息正文同号（都是 13），
  /// 侧栏与工作区读起来是同一层级。
  ///
  /// 实测交叉验证：Claude 侧栏「Athena 与 Claude 工作区 UI 对齐」
  /// 总宽 192 → 反推 12.6；按 14 算会得到 213，对不上。
  static const body = 13.0;

  /// 消息正文行高比例：`--cds-leading-prose`(20) / `--cds-font-size-prose`(13)。
  /// Claude 的行高是"绝对行盒"，不是随字号缩放的比例；
  /// 这里换算成 Flutter 的 `TextStyle.height`。
  static const proseHeight = 20.0 / prose;

  /// UI 正文行高比例：`--cds-leading-body`(19) / `--cds-font-size-body`(13)。
  static const bodyHeight = 19.0 / body;

  /// 标签、chip、小按钮（`--cds-font-size-body--sm` = 12）。
  static const label = 12.0;

  /// 说明、元信息（`--cds-font-size-caption` = 12）。
  static const caption = 12.0;

  /// 代码、工具名、参数（`--cds-font-size-code` = 12）。
  static const mono = 12.0;
}

/// 文字样式预设：一个角色 = 字号 + 默认字重（+ 行盒）。
///
/// 调用方只需补颜色：`AthenaTextStyle.section.copyWith(color: colors.textPrimary)`；
/// 字重与预设不同时再覆盖 `fontWeight`。角色与字号的对应见 [AthenaFontSize]，
/// 设计口径见 DESIGN.md §3。
///
/// 行高：只有 [prose]（消息正文）把 Claude 的绝对行盒（20）烧进预设；
/// [body] 不带行高——它多数时候是单行控件文字，多行时按需加
/// `height: AthenaFontSize.bodyHeight`（19 / 13）。
///
/// 等宽不在这里：代码 / 工具参数 / 输出走 [athenaMono]。
abstract final class AthenaTextStyle {
  /// 空态欢迎大标题：22 / w600。
  static const hero = TextStyle(
    fontSize: AthenaFontSize.hero,
    fontWeight: FontWeight.w600,
  );

  /// 页 / 对话框标题：15 / w600。
  static const title = TextStyle(
    fontSize: AthenaFontSize.title,
    fontWeight: FontWeight.w600,
  );

  /// 分区标题、卡片标题、列表项标题：14 / w500。
  static const section = TextStyle(
    fontSize: AthenaFontSize.section,
    fontWeight: FontWeight.w500,
  );

  /// 菜单条目、选择器行、设置行：14 / w400。
  static const row = TextStyle(
    fontSize: AthenaFontSize.row,
    fontWeight: FontWeight.w400,
  );

  /// 消息正文（Markdown）：13 / w400，行盒 20。
  static const prose = TextStyle(
    fontSize: AthenaFontSize.prose,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.proseHeight,
  );

  /// UI 正文、输入框、侧栏行：13 / w400。
  static const body = TextStyle(
    fontSize: AthenaFontSize.body,
    fontWeight: FontWeight.w400,
  );

  /// 标签、chip、小按钮、工具名：12 / w500。
  static const label = TextStyle(
    fontSize: AthenaFontSize.label,
    fontWeight: FontWeight.w500,
  );

  /// 说明、元信息、分组标题：12 / w400。
  static const caption = TextStyle(
    fontSize: AthenaFontSize.caption,
    fontWeight: FontWeight.w400,
  );
}

/// 全站字号档位（设置里的「Font size」）。
///
/// Claude 桌面端在 Appearance 里有一档文字大小设置（分段控件，Small / Medium /
/// Large）。本仓同样给三档，做法是整个应用叠一层 `TextScaler`：
/// **只缩放字号，不动几何**——放大到 1.15 倍时，侧栏行（高 26 / 字号 13）、
/// 设置导航行（高 32 / 字号 14）、列表行（高 40 / 字号 14）、分段控件与输入框
/// （高 32）都仍有余量，所以既有固定高度不必跟着改。
///
/// 它叠在系统无障碍缩放**之上**（见 `main.dart` 的 `applyTextSize`），不覆盖
/// 系统设置。
enum AthenaTextSize {
  small('Small', 0.85),
  medium('Medium', 1.0),
  large('Large', 1.15);

  /// 分段控件上的显示名。
  final String label;

  /// 相对默认档的字号系数。
  final double scale;

  const AthenaTextSize(this.label, this.scale);
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
  double? height,
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
