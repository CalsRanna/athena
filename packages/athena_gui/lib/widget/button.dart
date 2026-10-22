import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:athena_gui/widget/press_scale.dart';
import 'package:flutter/material.dart';

/// 导航图标按钮使用中性色块 + 描边，避免把次要导航也渲染成青瓷主操作。
///
/// 不用反色面（`surfaceRaised` + `iconOnRaised`）：反色面在浅色主题下是
/// 接近黑的深色，铺在单列画布上会成为整屏对比度最高的东西，一排顶栏按钮
/// 看起来就像一排黑色方块。中性色块仍然不是青瓷，不会和主操作抢强调。
class AthenaIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  const AthenaIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final iconWidget = Icon(
      icon,
      color: colors.textPrimary,
      size: AthenaIcon.regularSize,
    );
    final boxDecoration = BoxDecoration(
      color: colors.surfaceButtonSecondary,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(AthenaRadius.control),
    );
    final button = Container(
      decoration: boxDecoration,
      width: AthenaIconButtonSize.regular,
      height: AthenaIconButtonSize.regular,
      alignment: Alignment.center,
      child: iconWidget,
    );
    final targetSize = switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => AthenaIconButtonSize.touchTarget,
      _ => AthenaIconButtonSize.regular,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox.square(
          dimension: targetSize,
          child: Center(child: button),
        ),
      ),
    );
  }
}

class AthenaPrimaryButton extends StatefulWidget {
  final void Function()? onTap;
  final EdgeInsets padding;
  final Widget child;
  const AthenaPrimaryButton({super.key, this.onTap, required this.child})
    : padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 9);

  /// 行内小号（与 [AthenaSecondaryButton.small] 同尺度，高 32）。
  const AthenaPrimaryButton.small({super.key, this.onTap, required this.child})
    : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5);

  @override
  State<AthenaPrimaryButton> createState() => _AthenaPrimaryButtonState();
}

class _AthenaPrimaryButtonState extends State<AthenaPrimaryButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final disabled = widget.onTap == null;
    final foreground = disabled ? colors.textSecondary : colors.textOnAccent;
    return AthenaHover(
      enabled: !disabled,
      onTap: widget.onTap,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hover) {
        // 以配套前景保证青瓷底上的文字可读；hover 只轻微调整填充明度。
        final background = disabled
            ? colors.surfaceButtonSecondary
            : hover
            ? Color.alphaBlend(
                colors.surface.withValues(alpha: 0.08),
                colors.accent,
              )
            : colors.accent;
        return AthenaPressScale(
          enabled: !disabled,
          child: AnimatedContainer(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AthenaRadius.control),
            ),
            duration: AthenaMotion.hover,
            padding: widget.padding,
            child: DefaultTextStyle.merge(
              style: AthenaTextStyle.label.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: foreground,
                  size: AthenaIcon.inlineSize,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AthenaSecondaryButton extends StatefulWidget {
  final void Function()? onTap;
  final EdgeInsets padding;
  final Widget child;

  const AthenaSecondaryButton({super.key, this.onTap, required this.child})
    : padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  const AthenaSecondaryButton.small({
    super.key,
    this.onTap,
    required this.child,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);

  @override
  State<AthenaSecondaryButton> createState() => _AthenaSecondaryButtonState();
}

class _AthenaSecondaryButtonState extends State<AthenaSecondaryButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final disabled = widget.onTap == null;
    final foreground = disabled ? colors.textSecondary : colors.textPrimary;
    return AthenaHover(
      enabled: !disabled,
      onTap: widget.onTap,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hover) => AthenaPressScale(
        enabled: !disabled,
        child: AnimatedContainer(
          decoration: BoxDecoration(
            // 同样不能用 Colors.transparent：它的 RGB 是黑，插值会闪深色
            color: hover && !disabled
                ? colors.surfaceHover
                : colors.surfaceHover.withValues(alpha: 0),
            border: Border.all(
              color: hover && !disabled ? colors.borderStrong : colors.border,
            ),
            borderRadius: BorderRadius.circular(AthenaRadius.control),
          ),
          duration: AthenaMotion.hover,
          padding: widget.padding,
          child: DefaultTextStyle.merge(
            style: AthenaTextStyle.label.copyWith(color: foreground),
            child: IconTheme.merge(
              data: IconThemeData(
                color: foreground,
                size: AthenaIcon.inlineSize,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class AthenaTextButton extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  const AthenaTextButton({super.key, this.onTap, required this.text});

  @override
  State<AthenaTextButton> createState() => _AthenaTextButtonState();
}

class _AthenaTextButtonState extends State<AthenaTextButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return AthenaHover(
      onTap: widget.onTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AthenaPressScale(
        enabled: widget.onTap != null,
        child: AnimatedContainer(
          duration: AthenaMotion.hover,
          decoration: BoxDecoration(
            color: hover
                ? colors.surfaceHover
                : colors.surfaceHover.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AthenaRadius.control),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: AnimatedDefaultTextStyle(
            duration: AthenaMotion.hover,
            // 与 DefaultTextStyle.merge 同一口径：Animated 版本没有 merge 构造，
            // 这里手动并上环境样式，避免整体替换把字族等继承项丢掉。
            style: DefaultTextStyle.of(context).style.merge(
              AthenaTextStyle.label.copyWith(
                color: hover ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}

/// Ghost 行内按钮：静止无底色，hover 填充前景色 5%，圆角 [AthenaRadius.xs]，
/// 按下缩放交给 [AthenaPressScale]。
///
/// composer 工具行里那些「一段文字或一个裸字形、没有边框」的控件共用它；
/// 内边距由调用方给，因为 hover 底要按内容整形——纯文字按钮左右各 6、上下 3，
/// 裸字形补到 28 高的一圈。图标型 ghost 有固定方形盒，用
/// [AthenaGhostIconButton]。
class AthenaGhostButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// 填充与内容之间的内边距。点击区域就是这块填充，调用方要按「让 hover 底
  /// 看起来是一整块」来给，而不是按内容尺寸给。
  final EdgeInsetsGeometry padding;

  const AthenaGhostButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<AthenaGhostButton> createState() => _AthenaGhostButtonState();
}

class _AthenaGhostButtonState extends State<AthenaGhostButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 禁用态不给可操作反馈：填充、缩放、手型光标一起关掉
    final enabled = widget.onTap != null;
    return AthenaHover(
      enabled: enabled,
      onTap: widget.onTap,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, hover) => AthenaPressScale(
        enabled: enabled,
        child: AnimatedContainer(
          duration: AthenaMotion.hover,
          decoration: BoxDecoration(
            // 静止态用目标色的 0 透明度版；透明黑插值会先闪一下深色
            color: colors.textPrimary.withValues(alpha: hover ? 0.05 : 0),
            borderRadius: BorderRadius.circular(AthenaRadius.xs),
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Ghost 图标按钮：静止无底色，hover 填充前景色 5%，
/// 圆角 [AthenaRadius.row]。
///
/// 用于设置面板的关闭 / 新增键与桌面对话框的关闭键；默认盒 28、图标 14。
class AthenaGhostIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double box;
  final double iconSize;
  const AthenaGhostIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.box = AthenaIconButtonSize.compact,
    this.iconSize = AthenaIcon.inlineSize,
  });

  @override
  State<AthenaGhostIconButton> createState() => _AthenaGhostIconButtonState();
}

class _AthenaGhostIconButtonState extends State<AthenaGhostIconButton> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final icon = Icon(
      widget.icon,
      color: colors.textRowLabel,
      size: widget.iconSize,
    );
    return AthenaHover(
      onTap: widget.onTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AthenaPressScale(
        enabled: widget.onTap != null,
        child: AnimatedContainer(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // 静止态用目标色的 0 透明度版；透明黑插值会先闪深色
            color: colors.textPrimary.withValues(alpha: hover ? 0.05 : 0),
            borderRadius: BorderRadius.circular(AthenaRadius.row),
          ),
          duration: AthenaMotion.hover,
          height: widget.box,
          width: widget.box,
          child: icon,
        ),
      ),
    );
  }
}
