/// 设置面板专属的色板与几何，取值来自 **Claude 桌面端设置面板的实测**。
///
/// 采样方法：对 Claude 桌面端（macOS，浅色主题）的设置窗口整窗截图
/// （1296×783 逻辑窗口，2x Retina），再按像素量取并折半成逻辑值。
/// 该截图对本仓色板是**色彩准确**的——画布量到 `#FCFCFB`、面板内容量到
/// `#FFFFFF`、分组标题量到 `#898781`，与 [AthenaColors] 里已有的
/// `surface` / `surfaceMobile` / `textWeak` 完全一致，所以下面的新数值可信。
///
/// **为什么单独一套色板**：Claude 的**设置面板**用的是一组**中性灰**
/// （分隔线 `#F3F3F3`、控件描边 `#E7E7E7`、导航选中底 `#E3E3E2`），
/// 而 [AthenaColors] 里对应角色是**暖灰**（`divider` `#E1E0D9` 等）。
/// 暖灰铺在纯白面板上会偏黄，观感与 Claude 明显不同。
/// 这与 composer 边框单独定义（见 DESIGN.md §4 Composer）是同一条先例：
/// **白底上的中性灰单独定义，不动既有暖灰 token**。
///
/// 深色一套无法从浅色截图量取，是按同一语义镜像推导的（面板比画布亮一档、
/// 分隔线比内容底亮一档），并已被标注为推导值。
library;

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

  /// 导航标签字号。实测大写高 10.0 ≈ 13.9。
  static const navFontSize = 14.0;

  /// 分组标题字号。实测大写高 11.5（含 `p` 降部）≈ 12.4。
  static const navGroupFontSize = 12.0;

  /// 分组标题上方留白（搜索框底 89 → 标题顶 117）。实测 28。
  static const navGroupTopMargin = 28.0;

  /// 分组标题下方留白（标题底 128.5 → 首行顶 142）。实测 13.5。
  static const navGroupBottomMargin = 13.0;

  /// 搜索框：实测高 32（57..89）、宽 167（与导航行同宽）、圆角 8（估）。
  static const searchHeight = 32.0;
  static const searchRadius = 8.0;
  static const searchIconSize = 14.0;
  static const searchFontSize = 13.0;
  static const searchTopMargin = 13.0;

  // ---- 右侧内容区 ----
  /// 内容区左右内边距。实测左 24.5（标签起于 352.5，面板中线 328）、右 24。
  static const panePadding = 24.0;

  /// 内容区顶部内边距。实测标题顶 109，面板顶 44。
  static const paneTopPadding = 24.0;

  /// 分区标题字号。实测大写高 11.2 / 0.72 ≈ 15.6。
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

  /// 行标签与说明的字号。实测大写高均为 10.0 ≈ 13.9——**两者同号**。
  static const rowFontSize = 14.0;

  /// 行标签字重。Claude 的标签是半粗，说明是常规。
  static const rowLabelWeight = FontWeight.w600;

  /// 行说明的行高（14 号字在 22 行盒内）。
  static const rowDescriptionHeight = 1.5;

  /// 控件高。实测下拉框 153..185、分段轨道 476..508 均为 32。
  static const controlHeight = 32.0;

  /// 控件圆角。实测下拉框圆角弧约 8。
  static const controlRadius = 8.0;

  /// 控件文字字号。实测下拉框 14、分段 11–12。
  static const controlFontSize = 14.0;
  static const segmentFontSize = 12.0;

  /// 控件左内边距。实测下拉框文字起于 356，框左缘 353（该框为整行宽）。
  static const controlPaddingHorizontal = 12.0;

  /// 右侧控件列宽。实测分段控件 820..1136 = 316。
  static const controlColumnWidth = 316.0;

  /// 空搜索结果文字字号，与导航标签同号。
  static const fontSizeForEmptySearch = 14.0;

  /// 关闭按钮：字形约 10，内缩对齐内容区右缘（1136）与顶缘（68）。
  static const closeIconSize = 14.0;
  static const closeInset = 24.0;
}

/// 设置面板色板。
///
/// 浅色一套全部为截图实测；深色一套是同一语义的镜像推导。
@immutable
class AthenaSettingsColors extends ThemeExtension<AthenaSettingsColors> {
  /// 面板底色，也是右侧内容区底色。浅色实测 `#FFFFFF`（纯白）。
  final Color panel;

  /// 左侧导航底色。浅色实测 `#FCFCFB`。
  final Color nav;

  /// 导航与内容区的 1px 分界。浅色实测 `#E4E4E3`。
  final Color navDivider;

  /// 导航选中行底色。浅色实测 `#E3E3E2`。
  final Color navSelected;

  /// 导航选中行文字。浅色实测 `#0B0B0B`。
  final Color navSelectedText;

  /// 导航行静止文字与图标。浅色实测 `#52514F`（= 既有 `textRowLabel`）。
  final Color navText;

  /// 分组标题、搜索占位与图标、行说明。浅色实测 `#898781`（= 既有 `textWeak`）。
  final Color navMuted;

  /// 行之间的 1px 分隔线。浅色实测 `#F3F3F3`，只跨内容区左右内边距。
  final Color rule;

  /// 控件（下拉 / 输入 / 分段选中块）的 1px 描边。浅色实测 `#E7E7E7`。
  final Color controlBorder;

  /// 分段控件的轨道填充。浅色实测 `#F3F3F3`。
  final Color controlTrack;

  /// 分段控件选中块填充。浅色实测 `#FFFFFF`。
  final Color controlFill;

  /// 搜索框填充。浅色实测 `#FEFEFD`。
  final Color searchFill;

  /// 搜索框描边。浅色实测 `#E6E6E5`。
  final Color searchBorder;

  /// 面板外的遮罩色。
  final Color scrim;

  const AthenaSettingsColors({
    required this.panel,
    required this.nav,
    required this.navDivider,
    required this.navSelected,
    required this.navSelectedText,
    required this.navText,
    required this.navMuted,
    required this.rule,
    required this.controlBorder,
    required this.controlTrack,
    required this.controlFill,
    required this.searchFill,
    required this.searchBorder,
    required this.scrim,
  });

  static const light = AthenaSettingsColors(
    panel: Color(0xFFFFFFFF),
    nav: Color(0xFFFCFCFB),
    navDivider: Color(0xFFE4E4E3),
    navSelected: Color(0xFFE3E3E2),
    navSelectedText: Color(0xFF0B0B0B),
    navText: Color(0xFF52514F),
    navMuted: Color(0xFF898781),
    rule: Color(0xFFF3F3F3),
    controlBorder: Color(0xFFE7E7E7),
    controlTrack: Color(0xFFF3F3F3),
    controlFill: Color(0xFFFFFFFF),
    searchFill: Color(0xFFFEFEFD),
    searchBorder: Color(0xFFE6E6E5),
    scrim: Color(0x66000000),
  );

  /// 深色一套为镜像推导：面板比画布亮一档、导航比面板暗一档，
  /// 分隔线与描边比内容底亮一档（与既有的深色 `divider` 同向）。
  static const dark = AthenaSettingsColors(
    panel: Color(0xFF1E1E1D),
    nav: Color(0xFF151515),
    navDivider: Color(0xFF2C2C2A),
    navSelected: Color(0xFF2C2C2A),
    navSelectedText: Color(0xFFF6F6F4),
    navText: Color(0xFFA5A49A),
    navMuted: Color(0xFF898781),
    rule: Color(0xFF2A2A28),
    controlBorder: Color(0xFF383835),
    controlTrack: Color(0xFF2A2A28),
    controlFill: Color(0xFF383835),
    searchFill: Color(0xFF1E1E1D),
    searchBorder: Color(0xFF333331),
    scrim: Color(0x7A000000),
  );

  @override
  AthenaSettingsColors copyWith({
    Color? panel,
    Color? nav,
    Color? navDivider,
    Color? navSelected,
    Color? navSelectedText,
    Color? navText,
    Color? navMuted,
    Color? rule,
    Color? controlBorder,
    Color? controlTrack,
    Color? controlFill,
    Color? searchFill,
    Color? searchBorder,
    Color? scrim,
  }) {
    return AthenaSettingsColors(
      panel: panel ?? this.panel,
      nav: nav ?? this.nav,
      navDivider: navDivider ?? this.navDivider,
      navSelected: navSelected ?? this.navSelected,
      navSelectedText: navSelectedText ?? this.navSelectedText,
      navText: navText ?? this.navText,
      navMuted: navMuted ?? this.navMuted,
      rule: rule ?? this.rule,
      controlBorder: controlBorder ?? this.controlBorder,
      controlTrack: controlTrack ?? this.controlTrack,
      controlFill: controlFill ?? this.controlFill,
      searchFill: searchFill ?? this.searchFill,
      searchBorder: searchBorder ?? this.searchBorder,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AthenaSettingsColors lerp(
    ThemeExtension<AthenaSettingsColors>? other,
    double t,
  ) {
    if (other is! AthenaSettingsColors) return this;
    return AthenaSettingsColors(
      panel: Color.lerp(panel, other.panel, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      navDivider: Color.lerp(navDivider, other.navDivider, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navSelectedText: Color.lerp(navSelectedText, other.navSelectedText, t)!,
      navText: Color.lerp(navText, other.navText, t)!,
      navMuted: Color.lerp(navMuted, other.navMuted, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      controlTrack: Color.lerp(controlTrack, other.controlTrack, t)!,
      controlFill: Color.lerp(controlFill, other.controlFill, t)!,
      searchFill: Color.lerp(searchFill, other.searchFill, t)!,
      searchBorder: Color.lerp(searchBorder, other.searchBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// 取当前主题下的设置面板色板。
AthenaSettingsColors settingsColorsOf(BuildContext context) =>
    Theme.of(context).extension<AthenaSettingsColors>()!;
