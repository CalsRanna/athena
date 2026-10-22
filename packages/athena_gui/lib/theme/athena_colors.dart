import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 外观模式：青瓷色板的浅色 / 深色。
enum AthenaColorMode { light, dark }

/// Athena 青瓷语义色（由 [AthenaTheme] 注入，经 `context.athenaColors` 读取）。
///
/// 以中性瓷白 / 墨绿灰承载正文，青瓷强调色用于主操作、选中态与链接。
/// 实心强调色单独配套 [textOnAccent]，深色主题使用深色前景保证对比度；
/// [surfaceRaised] 仍是中性反色面，只供提示框与小型指示块使用；导航按钮
/// 与列表卡片走 `surfaceButtonSecondary` + `border`，避免浅色主题下出现
/// 大块接近黑色的反色面。
@immutable
class AthenaColors {
  // ---- 表面 ----
  final Color surface; // 主画布
  final Color surfacePanel; // 侧栏 / 顶栏 / 次级面板
  final Color surfaceMobile; // 对话框 / sheet / 弹出层
  final Color surfaceDeep; // 深层容器 / 未选中 chip 内层
  final Color surfaceRaised; // 中性反色面（提示框 / 小型指示块）
  final Color surfaceButtonSecondary; // 次级按钮底 / 中性色块
  final Color surfaceHover; // hover 态底
  final Color surfaceSelected; // 选中态底

  // ---- 文字 ----
  final Color textPrimary; // 主文字 / 关键图标
  final Color textInput; // 输入框文字
  final Color textSecondary; // 次级辅助文字
  final Color textWeak; // 最弱文字 / 占位
  final Color textRowLabel; // 列表行标签的静止色
  final Color dangerText; // 菜单危险项与校验错误文字
  final Color textOnRaised; // 中性反色面上的文字
  final Color textSecondaryOnRaised; // 中性反色面上的次级文字
  final Color textOnCode; // 代码类容器上的正文与代码文字
  final Color textSecondaryOnCode; // 代码类容器上的次级文字与图标

  // ---- 边框 / 分隔 ----
  final Color border; // 分隔线 / 容器描边
  final Color borderStrong; // 聚焦 / 激活边框
  final Color divider; // 分隔线
  /// 窗口外壳接缝：侧栏右边界与页脚，比容器轮廓更轻。
  final Color borderChrome;

  // ---- 设置与输入容器 ----
  // 沿用 neutral 命名区分控件角色；选中面使用青瓷浅填充。
  final Color neutralHairline; // 顶栏发丝线
  final Color neutralRule; // 设置分隔线 / 分段轨道 / 行 hover 底
  final Color neutralBorder; // composer / 设置控件 / 搜索框描边
  final Color neutralBorderStrong; // composer / 设置控件聚焦描边
  final Color neutralSelected; // 设置导航 / 列表选中底
  final Color neutralControlFill; // 分段选中块 / 下拉框底
  final Color scrim; // 设置面板遮罩：画布压 40% 黑

  // ---- 输入 ----
  final Color inputBackground; // 输入框底色

  // ---- 强调 ----
  final Color accent; // 青瓷强调（主操作 / 选中控件 / 发送键 / 运行中状态）
  final Color textOnAccent; // 实心青瓷底上的文字与图标

  // ---- 状态 ----
  final Color statusSuccess; // 成功结果
  final Color statusWarning; // 警告
  final Color statusError; // 错误

  // ---- 控件 ----
  final Color switchKnob; // 开关滑块
  final Color switchTrackOff; // 开关关闭轨道（中性填充）
  final Color checkboxOff; // Checkbox 未选中描边
  final Color iconSecondary; // 次级图标
  final Color iconOnRaised; // 中性反色面上的图标

  // ---- 阴影 ----
  final Color shadow; // 柔阴影基色（见 AthenaShadow）

  // ---- 代码 / 内容容器 ----
  final Color cardHeader; // 代码块语言条 / 表头 / 脚注头
  final Color codeBackground; // 代码块 / 引用块 / 工具输出底

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
    required this.textOnAccent,
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
    required this.markdownLink,
    required this.markdownStrikethrough,
    required this.markdownMath,
  });

  /// 浅色：瓷白画布、灰绿侧栏与深青瓷强调。
  static const light = AthenaColors(
    surface: Color(0xFFFAFBFA),
    surfacePanel: Color(0xFFF0F3F1),
    surfaceMobile: Color(0xFFFFFFFF),
    surfaceDeep: Color(0xFFEDF1EE),
    surfaceRaised: Color(0xFF202824),
    surfaceButtonSecondary: Color(0xFFEDF1EE),
    surfaceHover: Color(0xFFE6ECE8),
    surfaceSelected: Color(0xFFDEEEEA),
    textPrimary: Color(0xFF202824),
    textInput: Color(0xFF202824),
    textSecondary: Color(0xFF626E67),
    textWeak: Color(0xFF626E67),
    textRowLabel: Color(0xFF4F5F55),
    dangerText: Color(0xFF9F3636),
    textOnRaised: Color(0xFFFFFFFF),
    textSecondaryOnRaised: Color(0xFFA1AEA7),
    textOnCode: Color(0xFF202824),
    textSecondaryOnCode: Color(0xFF58675E),
    border: Color(0xFFDCE3DE),
    borderStrong: Color(0xFF83998C),
    divider: Color(0xFFDCE3DE),
    borderChrome: Color(0xFFE0E7E2),
    neutralHairline: Color(0xFFE8EEE9),
    neutralRule: Color(0xFFEDF1EE),
    neutralBorder: Color(0xFFDCE3DE),
    neutralBorderStrong: Color(0xFF83998C),
    neutralSelected: Color(0xFFDEEEEA),
    neutralControlFill: Color(0xFFFFFFFF),
    scrim: Color(0x66000000),
    inputBackground: Color(0xFFFFFFFF),
    accent: Color(0xFF0F766E),
    textOnAccent: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF35734A),
    statusWarning: Color(0xFF8E6019),
    statusError: Color(0xFFB24141),
    switchKnob: Color(0xFFFFFFFF),
    switchTrackOff: Color(0xFFDCE3DE),
    checkboxOff: Color(0xFF718078),
    iconSecondary: Color(0xFF626E67),
    iconOnRaised: Color(0xFFFFFFFF),
    shadow: Color(0xFF202824),
    cardHeader: Color(0xFFE6ECE8),
    codeBackground: Color(0xFFEDF1EE),
    markdownLink: Color(0xFF0F766E),
    markdownStrikethrough: Color(0xFF626E67),
    markdownMath: Color(0xFF202824),
  );

  /// 深色：同一语义体系的深色镜像，避开纯黑。
  static const dark = AthenaColors(
    surface: Color(0xFF171B1A),
    surfacePanel: Color(0xFF121615),
    surfaceMobile: Color(0xFF202624),
    surfaceDeep: Color(0xFF121615),
    surfaceRaised: Color(0xFFE8EDE9),
    surfaceButtonSecondary: Color(0xFF232C27),
    surfaceHover: Color(0xFF2B3730),
    surfaceSelected: Color(0xFF213E38),
    textPrimary: Color(0xFFE8EDE9),
    textInput: Color(0xFFE8EDE9),
    textSecondary: Color(0xFFA1AEA7),
    textWeak: Color(0xFFA1AEA7),
    textRowLabel: Color(0xFFB5C2B9),
    dangerText: Color(0xFFEB9595),
    textOnRaised: Color(0xFF202824),
    textSecondaryOnRaised: Color(0xFF4F5F55),
    textOnCode: Color(0xFFE8EDE9),
    textSecondaryOnCode: Color(0xFFAFBCB4),
    border: Color(0xFF35413B),
    borderStrong: Color(0xFF6D8778),
    divider: Color(0xFF35413B),
    borderChrome: Color(0xFF2A342E),
    neutralHairline: Color(0xFF2A342E),
    neutralRule: Color(0xFF232C27),
    neutralBorder: Color(0xFF35413B),
    neutralBorderStrong: Color(0xFF6D8778),
    neutralSelected: Color(0xFF213E38),
    neutralControlFill: Color(0xFF2B3730),
    scrim: Color(0x7A000000),
    inputBackground: Color(0xFF202624),
    accent: Color(0xFF65C7BC),
    textOnAccent: Color(0xFF10251F),
    statusSuccess: Color(0xFF8BC89D),
    statusWarning: Color(0xFFE5B975),
    statusError: Color(0xFFEB9595),
    switchKnob: Color(0xFFE8EDE9),
    switchTrackOff: Color(0xFF35413B),
    checkboxOff: Color(0xFF81978A),
    iconSecondary: Color(0xFFA1AEA7),
    iconOnRaised: Color(0xFF202824),
    shadow: Color(0xFF000000),
    cardHeader: Color(0xFF2B3730),
    codeBackground: Color(0xFF232C27),
    markdownLink: Color(0xFF65C7BC),
    markdownStrikethrough: Color(0xFFA1AEA7),
    markdownMath: Color(0xFFE8EDE9),
  );
}
