/// 设置面板的几何以窗口实测为起点，控件密度统一到 Athena。
///
/// 采样方法：对设置窗口（macOS，浅色主题）整窗截图
/// （1296×783 逻辑窗口，2x Retina），再按像素量取并折半成逻辑值。
/// 几何沿用参照并适度放松，排版直接使用 AthenaTextStyle 预设，颜色使用青瓷色板。
///
/// 设置面板的分隔线、控件描边、选中底等使用 AthenaColors 的 `neutral*`
/// 字段，与 composer 输入容器共用一套，见 DESIGN.md §2。
library;

import 'package:athena_gui/theme/athena_tokens.dart';

/// 设置面板的几何（不随主题变化）。
///
/// 保留参照值的项目标注实测来源，调整后的项目注明当前规则。
abstract final class AthenaSettings {
  // ---- 面板 ----
  /// 桌面设置共享同一尺寸；内容在面板内独立滚动。
  static const panelMaxWidth = 1024.0;
  static const panelMarginVertical = 32.0;

  /// 大面板统一使用 16 圆角。
  static const panelRadius = AthenaRadius.panel;

  /// 浅色面板遮罩：在当前画布上压 40% 黑。
  static const scrimOpacity = 0.40;

  // ---- 左侧导航 ----
  /// 侧栏固定宽度，含右侧分隔线。
  static const navWidth = 172.0;

  /// 侧栏内缩。
  static const navPadding = 10.0;

  /// 单行导航的点击高度。
  static const navRowHeight = 32.0;

  /// 导航行与全局列表行共用 8 圆角。
  static const navRowRadius = AthenaRadius.row;

  /// 导航图标相对行左缘的内缩。
  static const navRowPadding = 9.0;

  /// 导航图标。实测图标盒 16。
  static const navIconSize = AthenaIcon.regularSize;

  /// 导航图标与标签的距离。
  static const navIconGap = 8.0;

  /// 分组之间的留白。
  static const navGroupTopMargin = 14.0;

  /// 分组标签与首行的距离。
  static const navGroupBottomMargin = 4.0;

  /// 搜索框与设置控件同高，给 22 行盒留出上下呼吸空间。
  static const searchHeight = 36.0;
  static const searchRadius = AthenaRadius.control;
  static const searchIconSize = AthenaIcon.inlineSize;
  static const searchTopMargin = 13.0;

  // ---- 右侧内容区 ----
  /// 内容区左右内边距（文字列的内缩）。实测左 24.5（标签起于 352.5，
  /// 面板中线 328）、右 24。
  static const panePadding = 24.0;

  /// 行块相对文字列的外扩。可点行的 hover 底、选中底比文字列**每边宽 8**
  /// （列表行块比正文列宽一圈），所以内容区实际按
  /// `panePadding − rowInset` 内缩、每一行自带 `rowInset` 的水平内边距，
  /// 文字列仍落在 24 的位置上。
  static const rowInset = 8.0;

  /// 固定标题栏容纳页名、主要操作与关闭键。
  static const paneTopPadding = 60.0;

  /// 内容区底部内边距。
  static const paneBottomPadding = 40.0;

  /// 分区标题与首个控件的间距。实测标题底 123.5 → 首个控件顶 153（约 28，
  /// 分区标题与内容之间的留白。
  static const headingBottomMargin = 12.0;

  /// 相邻内容分区的间距。
  static const sectionGap = 24.0;

  /// 设置行上下内边距。
  static const rowPaddingVertical = 12.0;

  /// 标签与说明之间的间距。实测标签底 567 → 说明顶 577.5 = 10.5（行盒差）。
  static const rowLabelGap = 4.0;

  /// 控件高：22 行盒上下留出 14 的总空间。
  static const controlHeight = 36.0;

  /// 控件圆角与全局输入框、按钮一致。
  static const controlRadius = AthenaRadius.control;

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

  /// 关闭按钮：字形 14，内缩对齐内容区右缘（1136）与顶缘（68）。
  static const closeIconSize = AthenaIcon.inlineSize;
  static const closeInset = 15.0;

  /// 独立空态展示保留现有比例，不参与列表与操作图标的三档映射。
  static const emptyStateIconSize = 28.0;
}
