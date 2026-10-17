import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 桌面 hover 的公共骨架：状态机 + [MouseRegion] + [GestureDetector]。
///
/// 全库有 16 处「只有一个 hover 状态」的 State 类，各自写一遍
/// `bool hover` + `handleEnter`/`handleExit` + `MouseRegion` + `GestureDetector`
/// （约 12 行样板）。这里只收敛这段骨架——**装饰仍由调用方在 [builder] 里画**，
/// 因为各处的底色 / 描边 / 圆角 / 时长差异太大，硬塞进参数会得到一个参数比
/// 内容还多的包装。
///
/// 有 [onTap] 时同时提供按压缩放（0.975）：触屏没有 hover，按下状态是唯一的
/// 即时反馈。缩放只改绘制、不改布局，命中区域保持原样。整行宽的可点区域
/// （卡片标题行）用 [pressScale] 关掉它：大面积横向收缩会把内容从容器内边距里
/// 拽出来，看起来像在抖。
///
/// ```dart
/// AthenaHover(
///   onTap: widget.onTap,
///   builder: (context, hover) => AnimatedContainer(
///     duration: AthenaMotion.hover,
///     decoration: BoxDecoration(
///       color: hover ? colors.surfaceHover : colors.surfaceHover.withValues(alpha: 0),
///       borderRadius: BorderRadius.circular(AthenaRadius.row),
///     ),
///     child: content,
///   ),
/// )
/// ```
///
/// **[builder] 里不要用 `Colors.transparent` 做静止态**：它的 RGB 是黑，
/// [AnimatedContainer] 从它插值到浅色时会先闪一下深色。用目标色的
/// `withValues(alpha: 0)` 版本，RGB 全程一致、只有 alpha 在动。
/// （这是本条在本项目里被独立踩过多次的坑，注释只在这里留一份。）
class AthenaHover extends StatefulWidget {
  /// 用当前的 hover 状态构建子树。
  final Widget Function(BuildContext context, bool hover) builder;

  final VoidCallback? onTap;

  /// 右键。给了就同时接 `secondary` 语义。
  final void Function(TapUpDetails)? onSecondaryTap;

  /// 为 false 时不接 `onTap`、cursor 落回 [SystemMouseCursors.basic]。
  final bool enabled;

  /// 鼠标指针形状。`null`（默认）表示**不设置**，由父级决定（`MouseCursor.defer`）
  /// ——纯 hover 容器（如消息卡片：hover 只是显形操作条，本身不可点）用这个；
  /// 可点的控件显式传 [SystemMouseCursors.click]。
  final MouseCursor? cursor;

  /// 按下时是否缩放到 0.975。整行宽的可点区域（卡片标题行）应关掉：
  /// 0.975 落在几百像素宽的一行上就是十几像素的横向收缩，内容会明显离开容器边缘。
  final bool pressScale;

  const AthenaHover({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.enabled = true,
    this.cursor,
    this.pressScale = true,
  });

  @override
  State<AthenaHover> createState() => _AthenaHoverState();
}

class _AthenaHoverState extends State<AthenaHover> {
  bool hover = false;
  bool pressed = false;

  @override
  void didUpdateWidget(covariant AthenaHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 控件在按住期间被禁用（例如点了就进入 loading）时，按钮已经收不到
    // tap up；不在这里清掉，重新启用后会带着旧的按下态出现。
    if (pressed && (!widget.enabled || widget.onTap == null)) {
      pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.builder(context, hover);
    // 触屏没有 hover，按下状态是唯一的即时反馈；缩放只改绘制、不改布局，
    // 所以按钮的命中区域与按下前保持一致。
    final pressable = widget.enabled && widget.onTap != null;
    final visual = pressable && widget.pressScale
        ? AnimatedScale(
            scale: pressed ? 0.975 : 1,
            // 按下立刻跟手；回弹带弹簧，用标准档（DESIGN.md §6）。
            duration: pressed ? AthenaMotion.fast : AthenaMotion.hover,
            curve: pressed ? Curves.easeOut : Curves.easeOutBack,
            child: result,
          )
        : result;
    final region = MouseRegion(
      cursor: widget.cursor ?? MouseCursor.defer,
      onEnter: widget.enabled ? _handleEnter : null,
      onExit: widget.enabled ? _handleExit : null,
      child: visual,
    );
    if (widget.onTap == null && widget.onSecondaryTap == null) return region;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: pressable ? _handleTapDown : null,
      onTapUp: pressable ? _handleTapUp : null,
      onTapCancel: pressable ? _handleTapCancel : null,
      onTap: widget.enabled ? widget.onTap : null,
      onSecondaryTapUp: widget.onSecondaryTap,
      child: region,
    );
  }

  void _handleEnter(PointerEnterEvent _) => setState(() => hover = true);

  void _handleExit(PointerExitEvent _) => setState(() => hover = false);

  void _handleTapDown(TapDownDetails _) => setState(() => pressed = true);

  void _handleTapUp(TapUpDetails _) => setState(() => pressed = false);

  void _handleTapCancel() => setState(() => pressed = false);
}
