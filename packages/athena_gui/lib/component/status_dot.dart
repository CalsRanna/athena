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

  /// 循环走到 [t]（0..1）时的圆点颜色。
  ///
  /// **每帧只做一次 lerp**：首次调用先把整圈采样成 [_tableSteps] 档色表（每个 accent
  /// 只建一次，约 0.5ms），之后取相邻两档插值即可。同轮基准（`flutter_tester` 里的
  /// Dart 微基准，20 万次取均值）：本函数 0.07–0.11µs/次、单次 `Color.lerp` 0.124µs、
  /// 而"每帧现算等亮度色相旋转"是 1.243µs——多出来的全是 `computeLuminance` 里的
  /// `pow`（每次 3 个，`dart:ui` 自己注明它"computationally expensive"）。
  ///
  /// 建表时把明度按"相对亮度等于 accent"反解：同一个 HSL 明度下各色相的相对亮度
  /// 差很大（浅色主题实测：accent 对画布 4.3:1，沿用同一 L 的黄绿相位只有 1.5:1），
  /// 圆点会在一圈里"淡到看不见"再"亮回来"，那是在表达"闪烁"而不是"运行中"。
  ///
  /// `t == 0` 落到表头，也就是 accent 原色：动画停住 / 关掉时不会跳色。
  @visibleForTesting
  static Color colorAt(double t, AthenaColors colors) {
    final table = _tableFor(colors);
    final x = (t % 1) * _tableSteps;
    final index = x.floor() % _tableSteps;
    return Color.lerp(
      table[index],
      table[(index + 1) % _tableSteps],
      x - index,
    )!;
  }

  /// 整圈的采样档数。相邻两档之间是 RGB 直线（弦），档数越多越贴近"等亮度的色相圈"：
  /// 实测整圈的最大饱和度偏差 24 档 0.060 / 48 档 0.051 / 96 档 0.020，而亮度偏差
  /// 各档都稳定在 0.004（那是 8bit 颜色的量化下限，再加密也不会更小）。96 档建表约
  /// 0.5ms 且每帧代价与档数无关，所以取这个值。
  static const int _tableSteps = 96;

  /// 按 accent 记忆化的色表（浅色 / 深色各一张，进程内最多两条）。
  static final Map<int, List<Color>> _tables = {};

  static List<Color> _tableFor(AthenaColors colors) => _tables.putIfAbsent(
    colors.accent.toARGB32(),
    () => [
      for (var i = 0; i < _tableSteps; i++) _sample(i / _tableSteps, colors),
    ],
  );

  /// 建表用的单点采样：色相绕 [accent] 转 [t] 圈，**相对亮度钉在 accent 上**。
  ///
  /// 明度→相对亮度单调，所以按亮度二分反解明度。8 步（明度分辨率 1/256）就够：颜色
  /// 通道本身量化到 1/255，再细分也落不到新的色值上——实测整圈亮度偏差 12 步 0.0036、
  /// 8 步 0.0039，都是 8bit 的量化下限。
  static Color _sample(double t, AthenaColors colors) {
    final accent = HSLColor.fromColor(colors.accent);
    final hue = (accent.hue + t * 360) % 360;
    if (hue == accent.hue) return colors.accent;

    final target = colors.accent.computeLuminance();
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 8; i++) {
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
