import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 桌面 hover 的公共骨架：状态机 + [MouseRegion] + [GestureDetector]。
///
/// 全库有 16 处「只有一个 hover 状态」的 State 类，各自写一遍
/// `bool hover` + `handleEnter`/`handleExit` + `MouseRegion` + `GestureDetector`
/// （约 12 行样板）。这里只收敛这段骨架——**装饰仍由调用方在 [builder] 里画**，
/// 因为各处的底色 / 描边 / 圆角 / 时长差异太大，硬塞进参数会得到一个参数比
/// 内容还多的包装（见 AGENTS.md 对「卡片外壳」类的同类判断）。
///
/// ```dart
/// AthenaHover(
///   onTap: widget.onTap,
///   builder: (context, hover) => AnimatedContainer(
///     duration: const Duration(milliseconds: 120),
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

  const AthenaHover({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.enabled = true,
    this.cursor,
  });

  @override
  State<AthenaHover> createState() => _AthenaHoverState();
}

class _AthenaHoverState extends State<AthenaHover> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    Widget result = widget.builder(context, hover);
    var region = MouseRegion(
      cursor: widget.cursor ?? MouseCursor.defer,
      onEnter: widget.enabled ? _handleEnter : null,
      onExit: widget.enabled ? _handleExit : null,
      child: result,
    );
    if (widget.onTap == null && widget.onSecondaryTap == null) return region;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onSecondaryTapUp: widget.onSecondaryTap,
      child: region,
    );
  }

  void _handleEnter(PointerEnterEvent _) => setState(() => hover = true);

  void _handleExit(PointerExitEvent _) => setState(() => hover = false);
}
