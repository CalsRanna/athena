/// Athena 的设计 token：几何、排版、字体族、阴影。
///
/// 与 [AthenaColors] 的分工：`athena_colors.dart` 管颜色（挂 ThemeExtension，
/// 随主题切换），本文件管不随主题变化的常量。
///
/// Athena 青瓷主题的视觉规则：
/// - UI 与正文走平台默认字体，等宽只用于代码块与运行统计（Fira Code）；
/// - 圆角按角色分为 4 / 8 / 12 / 16，筛选 chip 与头像保留胶囊 / 圆形；
/// - 静态内容靠底色与细线分层，输入区、菜单、模态依次使用三档柔阴影；
/// - 画布使用青瓷中性色，输入框聚焦时使用青瓷强调色边框。
library;

import 'package:flutter/material.dart';

/// 圆角等级：同类组件共用数值，嵌套菜单用外层 12 + 内边距 4 + 行 8。
///
/// | 值 | token | 组件 |
/// |---|---|---|
/// | 4 | `xs` / `inline` | 徽标、行内代码、勾选框 |
/// | 8 | `row` / `control` | 列表行、按钮、输入框 |
/// | 12 | `container` / `menu` / `composer` | 卡片、代码块、菜单、输入区 |
/// | 16 | `panel` | 对话框、设置面板、底部面板 |
/// | 999 | `pill` | chip、发送按钮、头像 |
abstract final class AthenaRadius {
  static const xs = 4.0;
  static const inline = xs;
  static const row = 8.0;
  static const control = 8.0;
  static const container = 12.0;
  static const panel = 16.0;
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

  /// 桌面左侧栏宽度。侧栏与画布的分界线在逻辑 287，即宽 288。
  static const sidebar = 288.0;
}

/// 通用图标按角色选档；控件内部标记与窗口控制的例外见 WIDGETS.md §2。
abstract final class AthenaIcon {
  static const inlineSize = 14.0;
  static const regularSize = 16.0;
  static const largeSize = 24.0;
  static const compactStroke = 1.5;
}

/// 图标按钮的可见盒子与触摸区域分开定义，避免统一外观时缩小点击范围。
abstract final class AthenaIconButtonSize {
  static const compact = 28.0;
  static const regular = 32.0;
  static const touchTarget = 48.0;
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
}

/// 文字样式预设：一个角色 = 字号 + 默认字重（+ 行盒）。
///
/// 调用方只需补颜色：`AthenaTextStyle.section.copyWith(color: colors.textPrimary)`；
/// 字重与预设不同时再覆盖 `fontWeight`。角色与字号的对应见 [AthenaFontSize]，
/// 设计口径见 DESIGN.md §3。
///
/// 每个预设都携带所属层级的行盒，组件不再各自覆盖比例行高。
///
/// **预设不写字族**，交给主题（[AthenaFont.ui] 为 `null`＝平台默认）。代码是
/// 唯一的例外，见 [AthenaTextSize.code]。
///
/// 每个预设都显式写明 `leadingDistribution: even`，而不是留空交给环境样式：
/// 行盒（22 / 18）比字体自身的 em 盒高，多出的部分 Flutter 默认按 ascender/
/// descender 比例分配（`proportional`），而系统字体的 ascender 明显大于
/// descender，于是这些像素几乎全压在字上方，字在行盒里整体偏下
/// （SF Pro 14/22 曾实测偏 2px）。`even` 上下平分，字形落在行盒中心。
///
/// 必须写在预设里：Material 的 `bodyMedium` 本来就带 `even`，但 `Text` 的
/// `style:` 参数与 `DefaultTextStyle`（替换式）会整体换掉环境样式，只有
/// `DefaultTextStyle.merge` 能继承到；同一个按钮走两条路径就会一个居中、
/// 一个偏低。写进预设后两条路径一致。
abstract final class AthenaTextStyle {
  /// 空态欢迎大标题：20 / 28 / w600。
  static const hero = TextStyle(
    fontSize: AthenaFontSize.hero,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.heroHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 页 / 对话框 / 设置分区标题：16 / 24 / w600。
  static const title = TextStyle(
    fontSize: AthenaFontSize.title,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.titleHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 卡片标题、列表项标题与表单标签：14 / 22 / w600。
  static const section = TextStyle(
    fontSize: AthenaFontSize.section,
    fontWeight: FontWeight.w600,
    height: AthenaFontSize.bodyHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 菜单条目、选择器行、设置行：14 / w400。
  static const row = TextStyle(
    fontSize: AthenaFontSize.row,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.bodyHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 消息正文（Markdown）：默认 14 / w400，行盒 22。
  static const prose = TextStyle(
    fontSize: AthenaFontSize.prose,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.proseHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// UI 正文、输入框、侧栏行：14 / 22 / w400。
  static const body = TextStyle(
    fontSize: AthenaFontSize.body,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.bodyHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 按钮、选择器与可操作标签：14 / 22 / w500。
  static const label = TextStyle(
    fontSize: AthenaFontSize.label,
    fontWeight: FontWeight.w500,
    height: AthenaFontSize.bodyHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 辅助说明、元信息、分组标题：12 / 18 / w400。
  static const caption = TextStyle(
    fontSize: AthenaFontSize.caption,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.captionHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 用等宽字体的元信息：运行统计、消息发送时刻。
  ///
  /// 与 [caption] 同号同行盒，只换字族。数字每秒都在变，等宽保证同位数字
  /// 宽度一致，整条标签不会随数值更新左右跳。
  ///
  /// 不跟随会话「Text size」档位：这是元信息，不是阅读内容，跟档位放大会
  /// 抢正文的注意力。代码块本身要跟档位，走 [AthenaTextSize.code]。
  static const captionCode = TextStyle(
    fontFamily: AthenaFont.code,
    fontFamilyFallback: AthenaFont.codeFallback,
    fontSize: AthenaFontSize.caption,
    fontWeight: FontWeight.w400,
    height: AthenaFontSize.captionHeight,
    leadingDistribution: TextLeadingDistribution.even,
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

  /// 消息里的代码块、行内代码与工具输出：与正文同号同卷，但换用 [AthenaFont.code]。
  ///
  /// 这里必须显式声明字族：主题其余部分走平台默认（比例字体），代码块需要
  /// 等宽来保证列对齐——ASCII 图、`=` 对齐的配置、右对齐的注释都依赖它。
  /// 中文（注释、工具输出的中文）按 [AthenaFont.codeFallback] 回退。
  TextStyle get code => prose.copyWith(
    fontFamily: AthenaFont.code,
    fontFamilyFallback: AthenaFont.codeFallback,
  );
}

/// 字体族：UI 走平台默认，只有代码与动态数值用打包的等宽字体。
///
/// [ui] 为 `null`＝平台默认（macOS SF Pro / Windows Segoe UI，含各自的中文
/// 回退）。侧栏、设置、按钮、正文、标题都走它——比例字体的中英文比例最自然，
/// 也符合「平台默认是对的，除非它有明确的错」。
///
/// [code] 是打包在 `asset/font/` 的 Fira Code，只服务两处：消息里的代码块与
/// 行内代码，以及助手消息底部的运行统计。这两处需要列对齐或数字不抖，等宽
/// 是功能需求而不是风格选择。
///
/// [Fira Code]: https://github.com/tonsky/FiraCode
abstract final class AthenaFont {
  /// UI、正文与标题：交给平台默认字体（含 CJK 回退）。
  static const String? ui = null;

  /// 显式指定 UI 字体时的中文回退链。
  static const uiFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
  ];

  /// 代码块、行内代码与运行统计：Fira Code。
  ///
  /// 只打包 Regular：用它的两处都取 w400，其他字重命中不了这个族。
  /// 它只含拉丁字母、数字与符号，不含 CJK——中文出现在代码块里时按
  /// [codeFallback] 回退。
  ///
  /// 无斜体文件，`em` 里的英文由 Flutter 合成倾斜。自带 `calt` 连字
  /// （`->`、`=>`、`!=` 渲染成单个字形），Flutter 默认启用。
  static const code = 'FiraCode';

  /// 代码里出现中文时的回退链。Fira Code 不含 CJK，代码块里的注释、
  /// 工具输出与统计里的中文都靠它。
  static const codeFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];
}

/// 过渡时长。**按感知档位分级，不按组件分级。**
///
/// 六个档位是"人眼能分辨的快慢"：60–100 是"瞬间"，150 是"一下"，240 是"缓缓"，
/// 500 是"渐变"，1800+ 是"持续循环"，3 秒是"停留"。**不要**为某个组件新加一个贴着自己名字的
/// 常量——差值在 20ms 以内的两档（如 140 与 150）人眼分不出，共用一档即可。
///
/// 选档只看两件事：**这是不是交互反馈**（是 → [hover]），**要不要跟手**
/// （指针已移开、收得要更快 → [fast]）。语义描述得再贴切，值也不能另开一档。
abstract final class AthenaMotion {
  /// 快档：100ms。用于**退场与按压**——指针已经移开或按下的那一刻，
  /// 用户已经在看下一个目标，收得慢会显得拖沓。
  ///
  /// 菜单 / 预览卡退场、按压缩放、预览卡弹出前的延迟，都用它。
  static const Duration fast = Duration(milliseconds: 100);

  /// 标准档：150ms。**交互反馈一律用它**：hover 底色、描边变色、分段切换、
  /// 行底变化、图标两态切换、浮层进场、聚焦变色。
  ///
  /// 全站同档不只是"好看"——指针划过一串不同控件时，同档才有统一手感。
  static const Duration hover = Duration(milliseconds: 150);

  /// 慢档：240ms。用于**位置与视口迁移**：滚动跳转到某一轮、回弹（`easeOutBack`）。
  /// 这类动画位移大，来得太快会让人失去空间感。
  static const Duration slow = Duration(milliseconds: 240);

  /// 渐变档：500ms。用于需要看清中间值的数值过渡。
  static const Duration slower = Duration(milliseconds: 500);

  /// 循环档：1800ms。**持续重复**的装饰动画绕一圈的时长（工具头 shimmer）。
  ///
  /// 比它更慢的循环（状态点色相 2400ms）在 `StatusDot.cycleDuration` 自持——
  /// 侧栏是常驻区域，圆点转太快会把注意力从正文抢走，这个差异是刻意的。
  static const Duration cycle = Duration(milliseconds: 1800);

  /// 停留档：3 秒。**瞬时提示在屏上留多久**（"已复制"的复原、桌面轻提示消失）。
  ///
  /// 这不是过渡时长，是可读性下限：短于它用户来不及看清。本档不参与"快慢"取舍。
  static const Duration linger = Duration(seconds: 3);
}

/// 浮起容器的柔阴影。
///
/// 静态卡片无阴影；两端 composer 用 [raised]，菜单 / 预览用 [overlay]，
/// 对话框 / 设置面板用 [modal]。深色浮层另加不占布局空间的 1px 轮廓。
abstract final class AthenaShadow {
  /// 贴近表面：composer、控件内的滑块。
  static List<BoxShadow> raised(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.03),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// 小浮层：弹出菜单、悬停预览、加载提示。
  static List<BoxShadow> overlay(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.04),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  /// 模态面板：配合遮罩表达层级。
  static List<BoxShadow> modal(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
