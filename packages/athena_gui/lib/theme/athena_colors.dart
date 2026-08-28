import 'package:flutter/material.dart';

/// 外观模式：深色（默认）/ 浅色。
enum AthenaColorMode { dark, light }

/// Athena 品牌语义色（挂载于 ThemeData.extensions）。
///
/// 字段按"语义角色"划分（一个角色一个字段，避免一个色值多角色冲突），
/// 深浅两套值遵循 DESIGN.md 的 Token Governance：
/// 浅色值从现有 token 按角色推导（灰阶镜像 / 透明度变体），不新增品牌色。
///
/// 深色主题中的"浅色表面"（白卡/白按钮）在浅色主题下保持浅色，
/// 因此部分字段（surfaceRaised / textOnRaised / iconOnRaised /
/// cardPrimaryBackground / cardPrimaryText）在两种模式下同值。
@immutable
class AthenaColors extends ThemeExtension<AthenaColors> {
  // ---- 表面 ----
  final Color surface; // 桌面主工作区背景
  final Color surfaceMobile; // 移动端主背景 / 对话框 / sheet 背景
  final Color surfaceDeep; // 深层容器 / 反白底 / Tag 未选中内层
  final Color surfaceRaised; // 白卡 / 白色按钮底（两种模式同值）
  final Color surfaceButtonSecondary; // 次级按钮底 / 中性色块

  // ---- 文字 ----
  final Color textPrimary; // 主文字 / 关键图标
  final Color textInput; // 输入框文字 / 亮色内容文本
  final Color textSecondary; // 次级辅助文字
  final Color textWeak; // 弱文字 / 时间戳
  final Color textOnRaised; // 白卡 / 白按钮上的深色文字（两种模式同值）
  final Color textSelected; // 选中态文字（Tag 选中时反转）

  // ---- 边框 / 分隔 ----
  final Color border; // 占位符 / 边框 / 弱图标
  final Color borderStrong; // 输入框描边 / 较强轮廓线
  final Color borderFaint; // 模块分割线 / 淡边框（使用点带 alpha）
  final Color divider; // 分隔线

  // ---- 输入 ----
  final Color inputBackground; // 输入框半透明背景基色（使用点带 alpha）

  // ---- 品牌 ----
  final Color teal; // Athena Teal 品牌强调
  final Color sage; // 开关开启底色
  final Color slate; // 开关关闭底色
  final Color ctaGlow; // CTA 光晕阴影基色（使用点带 alpha）

  // ---- 组件 ----
  final Color tagBorderStart; // Tag 渐变边框起点（使用点带 alpha）
  final Color tagSelectedBackground; // Tag 选中背景
  final Color cardHeader; // 工具卡 / 思考卡 header 底
  final Color avatarBackground; // 头像圆底（两种模式下均需与卡底区分）
  final Color codeBackground; // 代码块 / 浅色容器填充
  final Color checkboxOff; // Checkbox 未选中勾色
  final Color iconSecondary; // 次级图标
  final Color iconOnRaised; // 白底上的图标（两种模式同值）
  final Color cardPrimaryBackground; // 白卡上的主按钮底（两种模式同值）
  final Color cardPrimaryText; // 白卡主按钮文字（两种模式同值）
  final Color markdownLink; // Markdown 链接文字
  final Color markdownStrikethrough; // Markdown 删除线文字与装饰线
  final Color markdownMath; // Markdown 数学公式

  const AthenaColors({
    required this.surface,
    required this.surfaceMobile,
    required this.surfaceDeep,
    required this.surfaceRaised,
    required this.surfaceButtonSecondary,
    required this.textPrimary,
    required this.textInput,
    required this.textSecondary,
    required this.textWeak,
    required this.textOnRaised,
    required this.textSelected,
    required this.border,
    required this.borderStrong,
    required this.borderFaint,
    required this.divider,
    required this.inputBackground,
    required this.teal,
    required this.sage,
    required this.slate,
    required this.ctaGlow,
    required this.tagBorderStart,
    required this.tagSelectedBackground,
    required this.cardHeader,
    required this.avatarBackground,
    required this.codeBackground,
    required this.checkboxOff,
    required this.iconSecondary,
    required this.iconOnRaised,
    required this.cardPrimaryBackground,
    required this.cardPrimaryText,
    required this.markdownLink,
    required this.markdownStrikethrough,
    required this.markdownMath,
  });

  /// 深色（默认，保持历史色值逐字节不变）。
  static const dark = AthenaColors(
    surface: Color(0xFF282828),
    surfaceMobile: Color(0xFF282F32),
    surfaceDeep: Color(0xFF161616),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceButtonSecondary: Color(0xFF616161),
    textPrimary: Color(0xFFFFFFFF),
    textInput: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9E9E9E),
    textWeak: Color(0xFFCACACA),
    textOnRaised: Color(0xFF161616),
    textSelected: Color(0xFF161616),
    border: Color(0xFFC2C2C2),
    borderStrong: Color(0xFF757575),
    borderFaint: Color(0xFFFFFFFF),
    divider: Color(0xFFEDEDED),
    inputBackground: Color(0xFFADADAD),
    teal: Color(0xFF6ABEB9),
    sage: Color(0xFFA7BA88),
    slate: Color(0xFFC2C9D1),
    ctaGlow: Color(0xFFCED2C7),
    tagBorderStart: Color(0xFFEAEAEA),
    tagSelectedBackground: Color(0xFFE0E0E0),
    cardHeader: Color(0xFFE0E0E0),
    avatarBackground: Color(0xFF282F32),
    codeBackground: Color(0xFFEDEDED),
    checkboxOff: Color(0xFFD0D5DD),
    iconSecondary: Color(0xFFE0E0E0),
    iconOnRaised: Color(0xFF000000),
    cardPrimaryBackground: Color(0xFF282F32),
    cardPrimaryText: Color(0xFFFFFFFF),
    markdownLink: Color(0xFF6ABEB9),
    markdownStrikethrough: Color(0xFF9E9E9E),
    markdownMath: Color(0xFF161616),
  );

  /// 浅色（从现有 token 按角色推导）。
  static const light = AthenaColors(
    surface: Color(0xFFFAFBFC),
    surfaceMobile: Color(0xFFFDFDFE),
    surfaceDeep: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceButtonSecondary: Color(0xFFF2F3F5),
    textPrimary: Color(0xFF1C1C1C),
    textInput: Color(0xFF333333),
    textSecondary: Color(0xFF6E6E6E),
    textWeak: Color(0xFF757575),
    textOnRaised: Color(0xFF161616),
    textSelected: Color(0xFF161616),
    border: Color(0xFFB0B0B0),
    borderStrong: Color(0xFFC2C2C2),
    borderFaint: Color(0xFF8A8A8A),
    divider: Color(0xFFE8E9EB),
    inputBackground: Color(0xFFF3F4F6),
    teal: Color(0xFF4FA8A3),
    sage: Color(0xFF7E9A5F),
    slate: Color(0xFFB0B8C0),
    ctaGlow: Color(0xFFADADAD),
    tagBorderStart: Color(0xFF1C1C1C),
    tagSelectedBackground: Color(0xFFE0E0E0),
    // header（cardHeader）比正文（codeBackground）略深，保持层次区分
    cardHeader: Color(0xFFE9EAEC),
    avatarBackground: Color(0xFFE0E0E0),
    codeBackground: Color(0xFFEFF0F2),
    checkboxOff: Color(0xFFB8C0C8),
    iconSecondary: Color(0xFF4D4D4D),
    iconOnRaised: Color(0xFF000000),
    cardPrimaryBackground: Color(0xFF282F32),
    cardPrimaryText: Color(0xFFFFFFFF),
    markdownLink: Color(0xFF4FA8A3),
    markdownStrikethrough: Color(0xFF757575),
    markdownMath: Color(0xFF333333),
  );

  @override
  AthenaColors copyWith({
    Color? surface,
    Color? surfaceMobile,
    Color? surfaceDeep,
    Color? surfaceRaised,
    Color? surfaceButtonSecondary,
    Color? textPrimary,
    Color? textInput,
    Color? textSecondary,
    Color? textWeak,
    Color? textOnRaised,
    Color? textSelected,
    Color? border,
    Color? borderStrong,
    Color? borderFaint,
    Color? divider,
    Color? inputBackground,
    Color? teal,
    Color? sage,
    Color? slate,
    Color? ctaGlow,
    Color? tagBorderStart,
    Color? tagSelectedBackground,
    Color? cardHeader,
    Color? avatarBackground,
    Color? codeBackground,
    Color? checkboxOff,
    Color? iconSecondary,
    Color? iconOnRaised,
    Color? cardPrimaryBackground,
    Color? cardPrimaryText,
    Color? markdownLink,
    Color? markdownStrikethrough,
    Color? markdownMath,
  }) {
    return AthenaColors(
      surface: surface ?? this.surface,
      surfaceMobile: surfaceMobile ?? this.surfaceMobile,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceButtonSecondary:
          surfaceButtonSecondary ?? this.surfaceButtonSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textInput: textInput ?? this.textInput,
      textSecondary: textSecondary ?? this.textSecondary,
      textWeak: textWeak ?? this.textWeak,
      textOnRaised: textOnRaised ?? this.textOnRaised,
      textSelected: textSelected ?? this.textSelected,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      borderFaint: borderFaint ?? this.borderFaint,
      divider: divider ?? this.divider,
      inputBackground: inputBackground ?? this.inputBackground,
      teal: teal ?? this.teal,
      sage: sage ?? this.sage,
      slate: slate ?? this.slate,
      ctaGlow: ctaGlow ?? this.ctaGlow,
      tagBorderStart: tagBorderStart ?? this.tagBorderStart,
      tagSelectedBackground:
          tagSelectedBackground ?? this.tagSelectedBackground,
      cardHeader: cardHeader ?? this.cardHeader,
      avatarBackground: avatarBackground ?? this.avatarBackground,
      codeBackground: codeBackground ?? this.codeBackground,
      checkboxOff: checkboxOff ?? this.checkboxOff,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconOnRaised: iconOnRaised ?? this.iconOnRaised,
      cardPrimaryBackground:
          cardPrimaryBackground ?? this.cardPrimaryBackground,
      cardPrimaryText: cardPrimaryText ?? this.cardPrimaryText,
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
      surfaceMobile: Color.lerp(surfaceMobile, other.surfaceMobile, t)!,
      surfaceDeep: Color.lerp(surfaceDeep, other.surfaceDeep, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceButtonSecondary: Color.lerp(
        surfaceButtonSecondary,
        other.surfaceButtonSecondary,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textInput: Color.lerp(textInput, other.textInput, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textWeak: Color.lerp(textWeak, other.textWeak, t)!,
      textOnRaised: Color.lerp(textOnRaised, other.textOnRaised, t)!,
      textSelected: Color.lerp(textSelected, other.textSelected, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderFaint: Color.lerp(borderFaint, other.borderFaint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      ctaGlow: Color.lerp(ctaGlow, other.ctaGlow, t)!,
      tagBorderStart: Color.lerp(tagBorderStart, other.tagBorderStart, t)!,
      tagSelectedBackground: Color.lerp(
        tagSelectedBackground,
        other.tagSelectedBackground,
        t,
      )!,
      cardHeader: Color.lerp(cardHeader, other.cardHeader, t)!,
      avatarBackground: Color.lerp(
        avatarBackground,
        other.avatarBackground,
        t,
      )!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      checkboxOff: Color.lerp(checkboxOff, other.checkboxOff, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconOnRaised: Color.lerp(iconOnRaised, other.iconOnRaised, t)!,
      cardPrimaryBackground: Color.lerp(
        cardPrimaryBackground,
        other.cardPrimaryBackground,
        t,
      )!,
      cardPrimaryText: Color.lerp(cardPrimaryText, other.cardPrimaryText, t)!,
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
