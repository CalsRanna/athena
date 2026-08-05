import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// 消息卡片:用左侧彩色竖条(纯色色块)区分消息类型,
/// 不使用文字前缀("你"/"Athena"/"[思考]"),也不使用 DecoratedBox 边框。
///
/// 为什么不用边框:nocterm 的 `RenderDecoratedBox` 把任意边框(即使只有
/// left)统一按"四边各 1 单位"布局,导致卡片上下各多 1 行占位,卡片间距
/// 被撑大。用 Row + 色块竖条则完全由布局高度决定,间距精确可控。
///
/// 竖条实现:Row 的第一个子项是**半块色块字符**(`█`/`▌`/`▎`/`▏`),
/// 前景色着 color。终端 cell 背景色只能整格填充,无法裁剪半宽;但
/// 半块字符本身就在 cell 内只涂部分宽度(█ 100%、▌ 50%、▎ 25%、
/// ▏ 12.5%),因此用不同字符即可自定义纯色竖条的视觉宽度。
/// 多行内容时竖条字符按行数重复(`▌\n▌\n…`),贯穿所有行。
class MessageCard extends StatelessComponent {
  const MessageCard({
    super.key,
    required this.color,
    required this.child,
    this.borderWidth = 0.5,
    this.verticalPadding = 1,
  });

  /// 左侧竖条颜色。
  final Color color;

  /// 卡片内容(多行文本等)。
  final Component child;

  /// 竖条视觉宽度(0~1,占 1 字符的比例):
  /// 1.0 → █、0.5 → ▌、0.25 → ▎、0.125 → ▏
  final double borderWidth;

  /// 卡片整体上下内边距(行数,取整)。估算竖条长度时计入。
  final double verticalPadding;

  /// 半块色块字符(按覆盖比例从宽到窄)。
  static const _barChars = <(double, String)>[
    (1.0, '█'),
    (0.5, '▌'),
    (0.25, '▎'),
    (0.125, '▏'),
  ];

  @override
  Component build(BuildContext context) {
    final barChar = _barChars
        .firstWhere((c) => borderWidth >= c.$1, orElse: () => _barChars.last)
        .$2;

    // 估算总行数:内容行数 + 上下 padding(各自取整为行数,
    // 0.5 上下各取整 1 行 = 2 行,不能合并后取整)。
    final estimatedLines = _estimateLines(child) + verticalPadding.round() * 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 半块色块竖条:前景色 + 按行数重复的半块字符
        Text(
          List.generate(math.max(1, estimatedLines), (_) => barChar).join('\n'),
          style: TextStyle(color: color),
        ),
        // padding 包内容(不在 Row 外层),竖条才能贯穿 padding 行
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 1,
              vertical: verticalPadding,
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  /// 估算子组件占用的行数。支持 Text(按显式换行 + 软换行估算)、
  /// Column(子组件行数之和)与 Padding(垂直 padding 取整为行数),
  /// 其他组件按 1 行处理。
  static int _estimateLines(Component component) {
    if (component is Padding) {
      // 垂直 padding 在终端按 cell 取整,各占 1 行(0.5 也取整为 1)
      final v = component.padding.top + component.padding.bottom;
      final child = component.child;
      return (child == null ? 0 : _estimateLines(child)) + v.round();
    }
    if (component is Text) {
      final text = component.data;
      var count = 0;
      for (final para in text.split('\n')) {
        // 软换行:按可用宽度(约 60 字符)保守估算,向上取整
        count += math.max(1, (para.length / 60).ceil());
      }
      return count;
    }
    if (component is Column) {
      var count = 0;
      for (final c in component.children) {
        count += _estimateLines(c);
      }
      return count;
    }
    return 1;
  }
}
