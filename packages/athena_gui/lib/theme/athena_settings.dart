/// 设置面板专属的几何与排版，取值来自 **Claude 桌面端设置面板的实测**。
///
/// 采样方法：对 Claude 桌面端（macOS，浅色主题）的设置窗口整窗截图
/// （1296×783 逻辑窗口，2x Retina），再按像素量取并折半成逻辑值。
/// 该截图对本仓色板是**色彩准确**的——画布量到 `#FCFCFB`、面板内容量到
/// `#FFFFFF`、分组标题量到 `#898781`，与 [AthenaColors] 里的
/// `surface` / `surfaceMobile` / `textWeak` 完全一致。
///
/// 颜色不在这里：设置面板用的那组**中性灰**（分隔线、控件描边、选中底等）
/// 已收进 [AthenaColors] 的 `neutral*` 字段，与 composer 输入容器共用一套，
/// 见 DESIGN.md §2「白底上的中性灰」。
library;

import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 设置面板的几何与排版（不随主题变化）。
///
/// 每一项都标注了实测值；未标注的为实测换算或对齐既有 token。
abstract final class AthenaSettings {
  // ---- 面板 ----
  /// 面板最大宽度。实测 1026（1296 宽窗口，左右各留 135）。
  static const panelMaxWidth = 1024.0;

  /// 面板与窗口上下的留白。实测上下各 44。
  static const panelMarginVertical = 44.0;

  /// 面板圆角。实测圆角弧长约 11–12。
  static const panelRadius = 12.0;

  /// 面板遮罩。实测面板外底色 `#979795`，正是画布 `#FCFCFB` 压 40% 黑，
  /// 即 `#FCFCFB × 0.6 = #979796`。
  static const scrimOpacity = 0.40;

  // ---- 左侧导航 ----
  /// 导航宽（含右侧 1px 分界线）。实测 192。
  static const navWidth = 192.0;

  /// 导航内边距。实测 12（行左缘 148，导航左缘 136）。
  static const navPadding = 12.0;

  /// 导航行高。实测选中行底色 241..273 = 32。
  static const navRowHeight = 32.0;

  /// 导航行距。实测行心距 33.5，即行高 32 + 间隙 2。
  static const navRowGap = 2.0;

  /// 导航行圆角。实测圆角弧约 7–8。
  static const navRowRadius = 8.0;

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

  /// 搜索框：实测高 32（57..89）、宽 167（与导航行同宽）、圆角 8（估）。
  static const searchHeight = 32.0;
  static const searchRadius = 8.0;
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

  /// 分区标题字号。实测大写高 11.2 / 0.72 ≈ 15.6。主字号表没有 16 这一档
  /// （见 DESIGN.md §3），它是设置面板独有的实测值。
  static const headingFontSize = 16.0;

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

  /// 行说明的行高（14 号字在 22 行盒内）。
  static const rowDescriptionHeight = 1.5;

  /// 控件高。实测下拉框 153..185、分段轨道 476..508 均为 32。
  static const controlHeight = 32.0;

  /// 控件圆角。实测下拉框圆角弧约 8。
  static const controlRadius = 8.0;

  /// 控件文字字号。实测下拉框 14、分段 11–12。
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

  /// 行内按钮高（Claude 的 `Manage` / `Export` 这类行尾按钮）。
  static const buttonHeight = 28.0;

  /// 空搜索结果文字字号，与导航标签同号。
  static const fontSizeForEmptySearch = AthenaFontSize.row;

  /// 关闭按钮：字形约 10，内缩对齐内容区右缘（1136）与顶缘（68）。
  static const closeIconSize = 14.0;
  static const closeInset = 15.0;
}
