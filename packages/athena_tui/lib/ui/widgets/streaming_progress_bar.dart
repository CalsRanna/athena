import 'dart:math' as math;

import 'package:athena_tui/ui/theme.dart';
import 'package:nocterm/nocterm.dart';

/// 流式生成时的循环动画进度条:一段亮块在条内从左到右往复扫描,
/// 表示正在 streaming(流式没有确定进度,因此不用百分比条)。
///
/// 用 [AnimationController.repeat] 循环驱动,[AnimatedBuilder] 每帧重建,
/// 亮块位置由动画值 0..1 映射,形成平滑的跑马灯效果。
class StreamingProgressBar extends StatefulComponent {
  const StreamingProgressBar({
    super.key,
    this.width = 20,
    this.pulseWidth = 6,
  });

  /// 进度条总宽度(字符数)。
  final int width;

  /// 亮块宽度(字符数)。
  final int pulseWidth;

  @override
  State<StreamingProgressBar> createState() => _StreamingProgressBarState();
}

class _StreamingProgressBarState extends State<StreamingProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final (before, pulse, after) = _marquee(
          _controller.value,
          component.width,
          component.pulseWidth,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(before, style: AthenaTextStyles.dim),
            Text(pulse, style: const TextStyle(color: AthenaColors.teal)),
            Text(after, style: AthenaTextStyles.dim),
          ],
        );
      },
    );
  }

  /// 把动画值 0..1 映射为跑马灯三段:暗块 / 亮块 / 暗块。
  ///
  /// 亮块从条左端滑入、滑到右端退出,单向循环。
  static (String, String, String) _marquee(
    double value,
    int barWidth,
    int pulseWidth,
  ) {
    final total = barWidth + pulseWidth; // 亮块完全滑入再滑出
    final pos = (value * total).floor(); // 亮块右边界
    final start = math.max(0, pos - pulseWidth).clamp(0, barWidth);
    final end = pos.clamp(0, barWidth);
    final beforeLen = start;
    final pulseLen = end - start;
    final afterLen = barWidth - end;
    return (
      '░' * beforeLen,
      '█' * pulseLen,
      '░' * afterLen,
    );
  }
}
