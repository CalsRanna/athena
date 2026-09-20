/// Codex 风格的设计 token：几何、排版、字体族、阴影。
///
/// 与 [AthenaColors] 的分工：`athena_colors.dart` 管颜色（挂 ThemeExtension，
/// 随主题切换），本文件管不随主题变化的常量。
///
/// 视觉语言来自 **真实的 Codex 桌面端**（取值来自对 Codex 窗口截图的实际采样）：
/// - UI 与正文用**系统字体**，等宽只用于代码块 / 终端 / 技术标签；
/// - 圆角偏大：行 8、容器 12、浮层 16、composer 20，chip 是胶囊；
/// - 层级靠"提亮一档的灰底 + 极淡的分隔线"，浮起容器带一层柔阴影；
/// - 画布是纯白（浅色）/ 近黑（深色），**不使用纯黑**。
library;

import 'package:flutter/material.dart';

/// 圆角等级。取值来自 **Claude 桌面端的 `--cds-radius-*`**。
///
/// Claude 的圆角比 Codex 更收：最小档 5、控件档 7、composer 也只有 12。
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
  static const sm = 5.0;
  static const md = 7.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const xxl = 14.0;
  static const xxxl = 16.0;
  static const xxxxl = 20.0;
  static const full = 999.0;
  static const pill = full;
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
/// 实测该变量的默认档（未叠加 `data-density` / `data-text-size`）是
/// caption 12 / body 14 / prose 15 / heading 14，字号比早期实现记的
/// （11 / 13 / 13）整体大一档。`prose` 是消息正文（Markdown）专用档，
/// 比 UI 正文再大 1px，这是 Claude 让对话内容比界面控件更易读的手段。
abstract final class AthenaFontSize {
  /// 空态标题。
  static const hero = 22.0;

  /// 页 / 对话框标题（`--cds-font-size-heading--textlg` = 15）。
  static const title = 15.0;

  /// 分区标题、卡片标题（`--cds-font-size-heading` = 14）。
  static const section = 14.0;

  /// **消息正文（Markdown）**：`--cds-font-size-prose` = 15。
  static const prose = 15.0;

  /// 正文、输入框（`--cds-font-size-body` = 14）。
  static const body = 14.0;

  /// 消息正文行高比例：`--cds-leading-prose`(22) / `--cds-font-size-prose`(15)
  /// ≈ 1.4667。Claude 的行高是"绝对行盒"，不是随字号缩放的比例；
  /// 这里换算成 Flutter 的 `TextStyle.height`。
  static const proseHeight = 22.0 / prose;

  /// 标签、chip、小按钮（`--cds-font-size-body--sm` = 12）。
  static const label = 12.0;

  /// 说明、元信息（`--cds-font-size-caption` = 12）。
  static const caption = 12.0;

  /// 代码、工具名、参数（`--cds-font-size-code` = 12）。
  static const mono = 12.0;
}

/// 字体族。
///
/// **UI 与正文走系统字体**（`null` = 平台默认：macOS SF Pro / Windows Segoe UI）——
/// Codex 的侧栏、设置、按钮、正文都是比例字体，等宽只有代码与终端在用。
/// 早期实现把整个 UI 做成等宽，是对 Codex 的误读。
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
/// Codex 的 composer 与浮层不是硬 1px 描边，而是一圈非常柔和的投影
/// （截图实测在边界处呈 `#FBFBFB → #F0F0F0 → #FFFFFF` 的渐变过渡）。
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
