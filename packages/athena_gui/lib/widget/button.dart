import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';

/// 导航图标按钮使用中性反色面，避免把次要导航也渲染成青瓷主操作。
class AthenaIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  const AthenaIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final iconWidget = Icon(
      icon,
      color: colors.iconOnRaised,
      size: AthenaIcon.regularSize,
    );
    final boxDecoration = BoxDecoration(
      color: colors.surfaceRaised,
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
        return AnimatedContainer(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AthenaRadius.control),
          ),
          duration: AthenaMotion.hover,
          padding: widget.padding,
          child: DefaultTextStyle(
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
      builder: (context, hover) => AnimatedContainer(
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
        child: DefaultTextStyle(
          style: AthenaTextStyle.label.copyWith(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground, size: AthenaIcon.inlineSize),
            child: widget.child,
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
      builder: (context, hover) => Container(
        decoration: BoxDecoration(
          // 这里用 Container（无动画）而不是 AnimatedContainer，颜色是瞬变的，
          // 所以 `Colors.transparent` 安全——不会有插值经过黑色的问题。
          color: hover ? colors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(AthenaRadius.control),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          widget.text,
          style: AthenaTextStyle.label.copyWith(
            color: hover ? colors.textPrimary : colors.textSecondary,
          ),
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
      builder: (context, hover) => AnimatedContainer(
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
    );
  }
}
