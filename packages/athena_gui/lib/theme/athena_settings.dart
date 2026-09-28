/// 设置面板的几何以 Claude 桌面端实测为起点，排版与控件密度统一到 Athena。
///
/// 采样方法：对 Claude 桌面端（macOS，浅色主题）的设置窗口整窗截图
/// （1296×783 逻辑窗口，2x Retina），再按像素量取并折半成逻辑值。
/// 几何沿用参照并适度放松，排版共用 Athena 的 14 / 22 基准，颜色使用青瓷色板。
///
/// 设置面板的分隔线、控件描边、选中底等使用 AthenaColors 的 `neutral*`
/// 字段，与 composer 输入容器共用一套，见 DESIGN.md 的 Colors 节。
library;

import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 设置面板的几何与排版（不随主题变化）。
///
/// 保留参照值的项目标注实测来源，调整后的项目注明当前规则。
abstract final class AthenaSettings {
  // ---- 面板 ----
  /// 面板最大宽度。实测 1026（1296 宽窗口，左右各留 135）。
  static const panelMaxWidth = 1024.0;

  /// 面板与窗口上下的留白。实测上下各 44。
  static const panelMarginVertical = 44.0;

  /// 大面板统一使用 16 圆角。
  static const panelRadius = AthenaRadius.panel;

  /// 浅色面板遮罩：在当前画布上压 40% 黑。
  static const scrimOpacity = 0.40;

  // ---- 左侧导航 ----
  /// 导航宽（含右侧 1px 分界线）。实测 192。
  static const navWidth = 192.0;

  /// 导航内边距。实测 12（行左缘 148，导航左缘 136）。
  static const navPadding = 12.0;

  /// 导航行高：22 行盒上下各留 7。
  static const navRowHeight = 36.0;

  /// 导航行距。
  static const navRowGap = 4.0;

  /// 导航行与全局列表行共用 8 圆角。
  static const navRowRadius = AthenaRadius.row;

  /// 导航行左内缩（图标起于行内 12）。实测行左缘 148、图标起于 160。
  static const navRowPadding = 12.0;

  /// 导航图标。实测图标盒 16。
  static const navIconSize = 16.0;

  /// 图标与标签间距。实测图标 160..176、文字起于 189。
  static const navIconGap = 12.0;

  /// 导航标签字号。实测大写高 10.0 ≈ 13.9，即 [AthenaFontSize.row]。
  static const navFontSize = AthenaFontSize.row;

  /// 分组标题字号。实测大写高 11.5（含 `p` 降部）≈ 12.4，即 [AthenaFontSize.caption]。
  static const navGroupFontSize = AthenaFontSize.caption;

  /// 分组标题上方留白（搜索框底 89 → 标题顶 117）。实测 28。
  static const navGroupTopMargin = 28.0;

  /// 分组标题下方留白（标题底 128.5 → 首行顶 142）。实测 13.5。
  static const navGroupBottomMargin = 13.0;

  /// 搜索框与设置控件同高，给 22 行盒留出上下呼吸空间。
  static const searchHeight = 36.0;
  static const searchRadius = AthenaRadius.control;
  static const searchIconSize = 14.0;
  static const searchFontSize = AthenaFontSize.body;
  static const searchTopMargin = 13.0;

  // ---- 右侧内容区 ----
  /// 内容区左右内边距（文字列的内缩）。实测左 24.5（标签起于 352.5，
  /// 面板中线 328）、右 24。
  static const panePadding = 24.0;

  /// 行块相对文字列的外扩。可点行的 hover 底、选中底比文字列**每边宽 8**
  /// （Claude 的列表行块比正文列宽一圈），所以内容区实际按
  /// `panePadding − rowInset` 内缩、每一行自带 `rowInset` 的水平内边距，
  /// 文字列仍落在 24 的位置上。
  static const rowInset = 8.0;

  /// 内容区顶部的**标题带**高度：关闭键（与返回链接）独占的一条。
  ///
  /// 实测首个分区标题顶 109、面板顶 44，即标题起于面板内 65；扣掉标题行盒
  /// 的上半留白取 60。旧值 24 会让首个标题与右上角的关闭键同一水平线，
  /// 分区标题右侧的控件（Provider 的启用开关）直接压在关闭键上。
  static const paneTopPadding = 60.0;

  /// 内容区底部内边距。
  static const paneBottomPadding = 40.0;

  /// 分区标题与页标题共用同一档。
  static const headingFontSize = AthenaFontSize.title;

  /// 分区标题与首个控件的间距。实测标题底 123.5 → 首个控件顶 153（约 28，
  /// 扣掉行盒自身的上下余量）。
  static const headingBottomMargin = 28.0;

  /// 分区之间的间距（上一分区末行 → 下一分区标题）。实测约 40。
  static const sectionGap = 40.0;

  /// 行上下内边距。实测规则线 536 → 标签顶 553.5 = 17.5，取 16。
  static const rowPaddingVertical = 16.0;

  /// 标签与说明之间的间距。实测标签底 567 → 说明顶 577.5 = 10.5（行盒差）。
  static const rowLabelGap = 4.0;

  /// 行标签与说明的字号。实测大写高均为 10.0 ≈ 13.9——**两者同号**，即 [AthenaFontSize.row]。
  static const rowFontSize = AthenaFontSize.row;

  /// 行标签字重。Claude 的标签是半粗，说明是常规。
  static const rowLabelWeight = FontWeight.w600;

  /// 行说明与常规 UI 共用 14 / 22。
  static const rowDescriptionHeight = AthenaFontSize.bodyHeight;

  /// 控件高：22 行盒上下留出 14 的总空间。
  static const controlHeight = 36.0;

  /// 控件圆角与全局输入框、按钮一致。
  static const controlRadius = AthenaRadius.control;

  /// 下拉、输入框与分段选择均使用常规 UI 字号。
  static const controlFontSize = AthenaFontSize.row;
  static const segmentFontSize = AthenaFontSize.label;

  /// 控件左内边距。实测下拉框文字起于 356，框左缘 353（该框为整行宽）。
  static const controlPaddingHorizontal = 12.0;

  /// 右侧控件列宽。实测分段控件 820..1136 = 316。
  static const controlColumnWidth = 316.0;

  /// 窄控件列宽：数字输入这类短值用它，免得一个三位数撑满 316 的框。
  static const controlNarrowWidth = 120.0;

  /// 宽控件列：下拉、密钥、URL 这类长值用它（比 316 再宽一档）。
  static const controlWideWidth = 360.0;

  /// 行内按钮高。
  static const buttonHeight = 32.0;

  /// 空搜索结果文字字号，与导航标签同号。
  static const fontSizeForEmptySearch = AthenaFontSize.row;

  /// 关闭按钮：字形约 10，内缩对齐内容区右缘（1136）与顶缘（68）。
  static const closeIconSize = 14.0;
  static const closeInset = 15.0;
}
