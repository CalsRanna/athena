import 'package:flutter/material.dart';

/// 外观模式：浅色（默认，对齐 Claude 桌面端的原生观感）/ 深色。
enum AthenaColorMode { light, dark }

/// Athena 语义色（挂载于 ThemeData.extensions）。
///
/// 取值来自 **Claude 桌面端 `app.asar` 里的 `--cds-*` 设计系统**
/// （`MainWindowPage-*.css`），并与窗口截图采样交叉验证。
///
/// Claude 的色板是一套**偏暖的中性灰**（`--cds-gray-0..900`），和普通
/// 中性灰一眼能分辨：白端带黄绿感（`#f9f9f7` / `#fcfcfb`），黑端是 `#0b0b0b`。
///
/// | 角色 | Claude 变量 | 值 |
/// |------|------------|-----|
/// | 画布 | `--cds-gray-10`（实测采样一致） | `#FCFCFB` |
/// | 侧栏 / 面板 | 实测采样 | `#FBFBF9`（与画布几乎无差） |
/// | 行 hover | 实测采样 | `#F0EFEC` |
/// | 行选中 | `--cds-gray-60` | `#EDECE9` |
/// | 弹出层 | `--cds-surface-2` = `gray-0` | `#FFFFFF` |
/// | 分隔线 / 描边 | `--cds-gray-100` | `#E1E0D9` |
/// | 主文字 | `--cds-gray-900` | `#0B0B0B` |
/// | 次级文字 | `--cds-gray-500` | `#6D6B67` |
/// | 弱文字 | `--cds-gray-400` | `#898781` |
/// | 强调 | `--cds-role-accent-fill` = `blue-450` | `#2A78D6` |
/// | 成功 / 警告 / 错误 | `green-400` / `orange-350` / `red-450` | `#0CA30C` / `#EB6834` / `#D03B3B` |
///
/// Claude 也用"基色 + alpha"派生：`--cds-alpha-0..9` 是 `neutral-900` 的
/// 0/5/10/20/35/50/60/70/85/95%。本仓对应的 hover / 选中底直接取灰阶档位。
@immutable
class AthenaColors extends ThemeExtension<AthenaColors> {
  // ---- 表面 ----
  final Color surface; // 主画布
  final Color surfacePanel; // 侧栏 / 顶栏 / 次级面板
  final Color surfaceMobile; // 对话框 / sheet / 弹出层
  final Color surfaceDeep; // 深层容器 / 未选中 chip 内层
  final Color surfaceRaised; // 主操作实心底（浅色=近黑，深色=白）
  final Color surfaceButtonSecondary; // 次级按钮底 / 中性色块
  final Color surfaceHover; // hover 态底
  final Color surfaceSelected; // 选中态底

  // ---- 文字 ----
  final Color textPrimary; // 主文字 / 关键图标
  final Color textInput; // 输入框文字
  final Color textSecondary; // 次级辅助文字
  final Color textWeak; // 最弱文字 / 占位
  final Color textRowLabel; // 列表行标签的静止色（Claude 用 gray-600，比次级文字更深）
  final Color dangerText; // 菜单危险项文字（Claude 用深红 #832F2B，比 statusError 深）
  final Color textOnRaised; // 主操作实心底上的文字
  final Color textSecondaryOnRaised; // 主操作实心底上的次级文字
  final Color textOnCode; // 代码类容器上的正文与代码文字
  final Color textSecondaryOnCode; // 代码类容器上的次级文字与图标

  // ---- 边框 / 分隔 ----
  final Color border; // 分隔线 / 容器描边
  final Color borderStrong; // 聚焦 / 激活边框
  final Color divider; // 分隔线
  /// 窗口外壳的分隔线：侧栏右边界、侧栏页脚上边。比 [border] 轻一档
  /// （neutral-900 5% 对 10%），因为外壳线是"面与面的接缝"，不是容器的轮廓。
  final Color borderChrome;

  // ---- 白底上的中性灰 ----
  //
  // Claude 的设置面板与 composer 输入容器用的是一组**中性灰**（neutral-900 的
  // alpha 阶：约 3% / 5% / 10% / 25%），不是侧栏那套暖灰——暖灰铺在纯白容器上
  // 会偏黄。浅色为实测值，深色按同一语义镜像推导（面板比画布亮一档、
  // 线比底亮一档）。
  final Color neutralHairline; // 顶栏底线：只比画布暗 5/255（实测 #F7F7F7）
  final Color neutralRule; // 设置面板的发丝分隔线 / 分段控件轨道 / 行 hover 底（实测 #F3F3F3）
  final Color
  neutralBorder; // 白底容器的 1px 描边：composer 常态、设置控件、搜索框、列表分界（实测 #E1E1E0–#E7E7E7，取中值 #E4E4E3）
  final Color neutralBorderStrong; // composer 聚焦描边（实测 #BFBFBE）
  final Color neutralSelected; // 设置导航 / 列表的选中行底（实测 #E3E3E2）
  final Color neutralControlFill; // 分段控件选中块 / 下拉框底：浅色纯白，深色比面板亮一档
  final Color scrim; // 设置面板遮罩：画布压 40% 黑

  // ---- 输入 ----
  final Color inputBackground; // 输入框底色

  // ---- 强调 ----
  final Color accent; // 全局唯一彩色强调（发送键 / 运行中状态点 / ColorScheme.primary）

  // ---- 状态 ----
  final Color statusSuccess; // 成功 / 开关开启
  final Color statusWarning; // 警告
  final Color statusError; // 错误

  // ---- 控件 ----
  final Color switchKnob; // 开关滑块
  final Color switchTrackOff; // 开关关闭轨道
  final Color checkboxOff; // Checkbox 未选中描边
  final Color iconSecondary; // 次级图标
  final Color iconOnRaised; // 主操作实心底上的图标

  // ---- 阴影 ----
  final Color shadow; // 柔阴影基色（见 AthenaShadow）

  // ---- 代码 / 内容容器 ----
  final Color cardHeader; // 代码块语言条 / 表头 / 脚注头
  final Color codeBackground; // 代码块 / 引用块 / 工具输出底
  final Color avatarBackground; // 头像圆底

  // ---- Markdown ----
  final Color markdownLink; // Markdown 链接文字
  final Color markdownStrikethrough; // Markdown 删除线
  final Color markdownMath; // Markdown 数学公式

  const AthenaColors({
    required this.surface,
    required this.surfacePanel,
    required this.surfaceMobile,
    required this.surfaceDeep,
    required this.surfaceRaised,
    required this.surfaceButtonSecondary,
    required this.surfaceHover,
    required this.surfaceSelected,
    required this.textPrimary,
    required this.textInput,
    required this.textSecondary,
    required this.textWeak,
    required this.textRowLabel,
    required this.dangerText,
    required this.textOnRaised,
    required this.textSecondaryOnRaised,
    required this.textOnCode,
    required this.textSecondaryOnCode,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.borderChrome,
    required this.neutralHairline,
    required this.neutralRule,
    required this.neutralBorder,
    required this.neutralBorderStrong,
    required this.neutralSelected,
    required this.neutralControlFill,
    required this.scrim,
    required this.inputBackground,
    required this.accent,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusError,
    required this.switchKnob,
    required this.switchTrackOff,
    required this.checkboxOff,
    required this.iconSecondary,
    required this.iconOnRaised,
    required this.shadow,
    required this.cardHeader,
    required this.codeBackground,
    required this.avatarBackground,
    required this.markdownLink,
    required this.markdownStrikethrough,
    required this.markdownMath,
  });

  /// 浅色（默认）：Claude 桌面端的原生观感。取值为 `--cds-*` 变量 + 截图实测。
  static const light = AthenaColors(
    surface: Color(0xFFFCFCFB),
    surfacePanel: Color(0xFFFBFBF9),
    surfaceMobile: Color(0xFFFFFFFF),
    surfaceDeep: Color(0xFFF3F3F0),
    surfaceRaised: Color(0xFF0B0B0B),
    surfaceButtonSecondary: Color(0xFFF0EFEC),
    surfaceHover: Color(0xFFF0EFEC),
    surfaceSelected: Color(0xFFEDECE9),
    textPrimary: Color(0xFF0B0B0B),
    textInput: Color(0xFF20201F),
    textSecondary: Color(0xFF6D6B67),
    textWeak: Color(0xFF898781),
    textRowLabel: Color(0xFF52514E),
    dangerText: Color(0xFF832F2B),
    textOnRaised: Color(0xFFFFFFFF),
    textSecondaryOnRaised: Color(0xFFA5A49A),
    textOnCode: Color(0xFF20201F),
    textSecondaryOnCode: Color(0xFF6D6B67),
    border: Color(0xFFE1E0D9),
    borderStrong: Color(0xFFC3C2B7),
    divider: Color(0xFFE1E0D9),
    borderChrome: Color(0xFFEFEFED),
    neutralHairline: Color(0xFFF7F7F7),
    neutralRule: Color(0xFFF3F3F3),
    neutralBorder: Color(0xFFE4E4E3),
    neutralBorderStrong: Color(0xFFBFBFBE),
    neutralSelected: Color(0xFFE3E3E2),
    neutralControlFill: Color(0xFFFFFFFF),
    scrim: Color(0x66000000),
    inputBackground: Color(0xFFFFFFFF),
    accent: Color(0xFF2A78D6),
    statusSuccess: Color(0xFF0CA30C),
    statusWarning: Color(0xFFEB6834),
    statusError: Color(0xFFD03B3B),
    switchKnob: Color(0xFFFFFFFF),
    switchTrackOff: Color(0xFFC3C2B7),
    checkboxOff: Color(0xFFB4B3A8),
    iconSecondary: Color(0xFF898781),
    iconOnRaised: Color(0xFFFFFFFF),
    shadow: Color(0xFF0B0B0B),
    cardHeader: Color(0xFFF0EFEC),
    codeBackground: Color(0xFFF6F6F4),
    avatarBackground: Color(0xFFE4E3DD),
    markdownLink: Color(0xFF256ABF),
    markdownStrikethrough: Color(0xFF898781),
    markdownMath: Color(0xFF0B0B0B),
  );

  /// 深色：同一语义体系的深色镜像，避开纯黑。
  static const dark = AthenaColors(
    surface: Color(0xFF1A1A19),
    surfacePanel: Color(0xFF151515),
    surfaceMobile: Color(0xFF1E1E1D),
    surfaceDeep: Color(0xFF151515),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceButtonSecondary: Color(0xFF2C2C2A),
    surfaceHover: Color(0xFF2C2C2A),
    surfaceSelected: Color(0xFF383835),
    textPrimary: Color(0xFFF6F6F4),
    textInput: Color(0xFFE7E6E1),
    textSecondary: Color(0xFFA5A49A),
    textWeak: Color(0xFF898781),
    textRowLabel: Color(0xFFA5A49A),
    dangerText: Color(0xFFE66767),
    textOnRaised: Color(0xFF0B0B0B),
    textSecondaryOnRaised: Color(0xFF5F5E5A),
    textOnCode: Color(0xFFE1E0D9),
    textSecondaryOnCode: Color(0xFFA5A49A),
    border: Color(0xFF2C2C2A),
    borderStrong: Color(0xFF454442),
    divider: Color(0xFF2C2C2A),
    borderChrome: Color(0xFF212121),
    neutralHairline: Color(0xFF212121),
    neutralRule: Color(0xFF2A2A28),
    neutralBorder: Color(0xFF2C2C2A),
    neutralBorderStrong: Color(0xFF454442),
    neutralSelected: Color(0xFF2C2C2A),
    neutralControlFill: Color(0xFF383835),
    scrim: Color(0x7A000000),
    inputBackground: Color(0xFF1E1E1D),
    accent: Color(0xFF5598E7),
    statusSuccess: Color(0xFF35B231),
    statusWarning: Color(0xFFF09978),
    statusError: Color(0xFFE66767),
    switchKnob: Color(0xFFFFFFFF),
    switchTrackOff: Color(0xFF454442),
    checkboxOff: Color(0xFF5F5E5A),
    iconSecondary: Color(0xFFA5A49A),
    iconOnRaised: Color(0xFF0B0B0B),
    shadow: Color(0xFF000000),
    cardHeader: Color(0xFF2C2C2A),
    codeBackground: Color(0xFF20201F),
    avatarBackground: Color(0xFF383835),
    markdownLink: Color(0xFF6DA7EC),
    markdownStrikethrough: Color(0xFF898781),
    markdownMath: Color(0xFFE1E0D9),
  );

  @override
  AthenaColors copyWith({
    Color? surface,
    Color? surfacePanel,
    Color? surfaceMobile,
    Color? surfaceDeep,
    Color? surfaceRaised,
    Color? surfaceButtonSecondary,
    Color? surfaceHover,
    Color? surfaceSelected,
    Color? textPrimary,
    Color? textInput,
    Color? textSecondary,
    Color? textWeak,
    Color? textRowLabel,
    Color? dangerText,
    Color? textOnRaised,
    Color? textSecondaryOnRaised,
    Color? textOnCode,
    Color? textSecondaryOnCode,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? borderChrome,
    Color? neutralHairline,
    Color? neutralRule,
    Color? neutralBorder,
    Color? neutralBorderStrong,
    Color? neutralSelected,
    Color? neutralControlFill,
    Color? scrim,
    Color? inputBackground,
    Color? accent,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusError,
    Color? switchKnob,
    Color? switchTrackOff,
    Color? checkboxOff,
    Color? iconSecondary,
    Color? iconOnRaised,
    Color? shadow,
    Color? cardHeader,
    Color? codeBackground,
    Color? avatarBackground,
    Color? markdownLink,
    Color? markdownStrikethrough,
    Color? markdownMath,
  }) {
    return AthenaColors(
      surface: surface ?? this.surface,
      surfacePanel: surfacePanel ?? this.surfacePanel,
      surfaceMobile: surfaceMobile ?? this.surfaceMobile,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceButtonSecondary:
          surfaceButtonSecondary ?? this.surfaceButtonSecondary,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      textPrimary: textPrimary ?? this.textPrimary,
      textInput: textInput ?? this.textInput,
      textSecondary: textSecondary ?? this.textSecondary,
      textWeak: textWeak ?? this.textWeak,
      textRowLabel: textRowLabel ?? this.textRowLabel,
      dangerText: dangerText ?? this.dangerText,
      textOnRaised: textOnRaised ?? this.textOnRaised,
      textSecondaryOnRaised:
          textSecondaryOnRaised ?? this.textSecondaryOnRaised,
      textOnCode: textOnCode ?? this.textOnCode,
      textSecondaryOnCode: textSecondaryOnCode ?? this.textSecondaryOnCode,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      borderChrome: borderChrome ?? this.borderChrome,
      neutralHairline: neutralHairline ?? this.neutralHairline,
      neutralRule: neutralRule ?? this.neutralRule,
      neutralBorder: neutralBorder ?? this.neutralBorder,
      neutralBorderStrong: neutralBorderStrong ?? this.neutralBorderStrong,
      neutralSelected: neutralSelected ?? this.neutralSelected,
      neutralControlFill: neutralControlFill ?? this.neutralControlFill,
      scrim: scrim ?? this.scrim,
      inputBackground: inputBackground ?? this.inputBackground,
      accent: accent ?? this.accent,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusError: statusError ?? this.statusError,
      switchKnob: switchKnob ?? this.switchKnob,
      switchTrackOff: switchTrackOff ?? this.switchTrackOff,
      checkboxOff: checkboxOff ?? this.checkboxOff,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconOnRaised: iconOnRaised ?? this.iconOnRaised,
      shadow: shadow ?? this.shadow,
      cardHeader: cardHeader ?? this.cardHeader,
      codeBackground: codeBackground ?? this.codeBackground,
      avatarBackground: avatarBackground ?? this.avatarBackground,
      markdownLink: markdownLink ?? this.markdownLink,
      markdownStrikethrough:
          markdownStrikethrough ?? this.markdownStrikethrough,
      markdownMath: markdownMath ?? this.markdownMath,
    );
  }

  @override
  AthenaColors lerp(ThemeExtension<AthenaColors>? other, double t) {
    if (other is! AthenaColors) return this;
    return AthenaColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfacePanel: Color.lerp(surfacePanel, other.surfacePanel, t)!,
      surfaceMobile: Color.lerp(surfaceMobile, other.surfaceMobile, t)!,
      surfaceDeep: Color.lerp(surfaceDeep, other.surfaceDeep, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceButtonSecondary: Color.lerp(
        surfaceButtonSecondary,
        other.surfaceButtonSecondary,
        t,
      )!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textInput: Color.lerp(textInput, other.textInput, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textWeak: Color.lerp(textWeak, other.textWeak, t)!,
      textRowLabel: Color.lerp(textRowLabel, other.textRowLabel, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      textOnRaised: Color.lerp(textOnRaised, other.textOnRaised, t)!,
      textSecondaryOnRaised: Color.lerp(
        textSecondaryOnRaised,
        other.textSecondaryOnRaised,
        t,
      )!,
      textOnCode: Color.lerp(textOnCode, other.textOnCode, t)!,
      textSecondaryOnCode: Color.lerp(
        textSecondaryOnCode,
        other.textSecondaryOnCode,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderChrome: Color.lerp(borderChrome, other.borderChrome, t)!,
      neutralHairline: Color.lerp(neutralHairline, other.neutralHairline, t)!,
      neutralRule: Color.lerp(neutralRule, other.neutralRule, t)!,
      neutralBorder: Color.lerp(neutralBorder, other.neutralBorder, t)!,
      neutralBorderStrong: Color.lerp(
        neutralBorderStrong,
        other.neutralBorderStrong,
        t,
      )!,
      neutralSelected: Color.lerp(neutralSelected, other.neutralSelected, t)!,
      neutralControlFill: Color.lerp(
        neutralControlFill,
        other.neutralControlFill,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
      switchKnob: Color.lerp(switchKnob, other.switchKnob, t)!,
      switchTrackOff: Color.lerp(switchTrackOff, other.switchTrackOff, t)!,
      checkboxOff: Color.lerp(checkboxOff, other.checkboxOff, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconOnRaised: Color.lerp(iconOnRaised, other.iconOnRaised, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      cardHeader: Color.lerp(cardHeader, other.cardHeader, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      avatarBackground: Color.lerp(
        avatarBackground,
        other.avatarBackground,
        t,
      )!,
      markdownLink: Color.lerp(markdownLink, other.markdownLink, t)!,
      markdownStrikethrough: Color.lerp(
        markdownStrikethrough,
        other.markdownStrikethrough,
        t,
      )!,
      markdownMath: Color.lerp(markdownMath, other.markdownMath, t)!,
    );
  }
}
