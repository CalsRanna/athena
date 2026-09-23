import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

/// 会话行的状态点。Claude 实测：静止 `#CAC8C4`、hover 加深到 `#8F8D89`，
/// 直径约 6 逻辑。用 `iconSecondary` 调透明度即可复现这两个档位。
///
/// **形状分两态**：没有在跑（静止 / hover / 重命名）画成 1px 描边的圆环，
/// 运行中（[streaming]）是实心点——形状本身就是一条不依赖颜色的状态线索。
///
/// 运行中的实心点额外带一条**色相循环**：色相绕 `accent` 转圈、相对亮度钉在 `accent`
/// 上，见 [colorAt]。只换色相是刻意的——换成另一组固定颜色（绿 / 橙）会被读成
/// `statusSuccess` / `statusWarning` 的语义，而"运行中"不是任何一种结果状态；
/// 亮度不动则是为了让圆点在一圈里始终有同一个视觉重量。
class StatusDot extends StatefulWidget {
  final bool hover;
  final bool streaming;
  final bool renaming;

  /// 色相绕一圈的时长。比 `StepHeaderShimmer` 的 1800ms 更慢：侧栏是常驻区域，
  /// 圆点转太快会把注意力从正文抢走。
  static const Duration cycleDuration = Duration(milliseconds: 2400);

  const StatusDot({
    super.key,
    required this.hover,
    required this.streaming,
    required this.renaming,
  });

  /// 循环走到 [t]（0..1）时的圆点颜色：色相绕 [accent] 转 [t] 圈，**相对亮度钉在
  /// accent 上**。
  ///
  /// 为什么不能直接沿用 accent 的 HSL 明度：同一个明度下各色相的相对亮度差很大
  /// （浅色主题实测：accent 对画布 4.3:1，而沿用同一 L 的黄绿相位只有 1.5:1），
  /// 圆点会在一圈里"淡到看不见"再"亮回来"，那是在表达"闪烁"而不是"运行中"。
  /// 这里改成按亮度反解明度（明度→亮度单调，二分即可），整圈对比度恒等于 accent。
  ///
  /// `t == 0` 直接返回原色：保证"动画停住 / 关掉"与 accent 完全一致，不留二分误差。
  @visibleForTesting
  static Color colorAt(double t, AthenaColors colors) {
    final accent = HSLColor.fromColor(colors.accent);
    final hue = (accent.hue + t * 360) % 360;
    if (hue == accent.hue) return colors.accent;

    final target = colors.accent.computeLuminance();
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 12; i++) {
      final mid = (low + high) / 2;
      final luminance = accent
          .withHue(hue)
          .withLightness(mid)
          .toColor()
          .computeLuminance();
      if (luminance < target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return accent.withHue(hue).withLightness((low + high) / 2).toColor();
  }

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StatusDot.cycleDuration,
  );

  /// 系统"减弱动态效果"时不开循环：运行中本身已经由颜色与文字说明，
  /// 循环只是冗余提示（与 `StepHeaderShimmer` 同一取舍）。
  bool _animationsDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming != widget.streaming) _syncAnimation();
  }

  /// 只有运行中才占一个 ticker：静止的侧栏行（数量多、常驻）不该持续重绘。
  void _syncAnimation() {
    if (widget.streaming && !_animationsDisabled) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (widget.streaming) {
      if (_animationsDisabled) return _dot(colors.accent);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) =>
            _dot(StatusDot.colorAt(_controller.value, colors)),
      );
    }

    final Color base;
    final double alpha;
    if (widget.renaming) {
      base = colors.statusWarning;
      alpha = 1;
    } else {
      base = colors.iconSecondary;
      alpha = widget.hover ? 0.75 : 0.45;
    }
    return _ring(base.withValues(alpha: alpha));
  }

  /// 运行中的实心圆点（颜色由 [colorAt] 逐帧给出）。
  Widget _dot(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// 不在跑的三态（静止 / hover / 重命名）是**圆环**：1px 描边、中间空心。
  ///
  /// 形状本身参与区分状态（不只靠颜色），同时让常驻的会话行退后一档——运行中的
  /// 实心点（还带色相循环）成为列表里唯一的实心焦点。外径仍是 6，行高不受影响。
  Widget _ring(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1),
    ),
  );
}
