import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';
// 说明:TextLayoutEngine 是 nocterm 内部 API(nocterm.dart 未导出),但
// RenderText 布局时用的正是这个引擎——import 内部路径使行数计算与
// 实际渲染共用同一换行与字符宽度算法,保证精确一致,而非另写一套
// 换行逻辑产生偏差。升级 nocterm 时若该路径变化,编译错误会立即暴露。
// ignore: implementation_imports
import 'package:nocterm/src/text/text_layout_engine.dart';

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
///
/// 竖条行数的精确计算:build 阶段拿不到布局宽度,无法知道软换行后
/// 的精确行数,所以用 LayoutBuilder 把 Row 的构建推迟到布局阶段,按
/// 实际约束宽度 + TextLayoutEngine(与 RenderText 共用)算出精确行数,
/// 而非按固定宽度估算。终端尺寸变化时 LayoutBuilder 自动用新约束
/// 重建,竖条行数随之精确更新。
class MessageCard extends StatefulComponent {
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

  @override
  State<MessageCard> createState() => _MessageCardState();
}

/// State:持有竖条行数缓存,流式期间历史消息内容引用不变时直接命中,
/// 跳过 build 阶段的全文 TextLayoutEngine.layout(渲染层按值去重不覆盖 build)。
class _MessageCardState extends State<MessageCard> {
  /// 半块色块字符(按覆盖比例从宽到窄)。
  static const _barChars = <(double, String)>[
    (1.0, '█'),
    (0.5, '▌'),
    (0.25, '▎'),
    (0.125, '▏'),
  ];

  /// 竖条占 1 列;水平 padding 左右各 1 列。计算文本可用宽度时的
  /// 扣除项,与实际布局链(Row → Expanded → Padding)保持一致。
  static const _barColumnWidth = 1.0;
  static const _horizontalPadding = 1.0;

  /// 宽度约束无界时(Row + Expanded 需要有限宽度,正常不会发生)的
  /// 兜底文本宽度。
  static const _fallbackTextWidth = 80;

  /// 文本测量缓存:key = (Text 在卡片树中的索引路径, 字符串引用, 宽度),
  /// value = 排版行数。
  ///
  /// 流式更新时 `_pendingList = [...base, message]` 只换列表、元素与
  /// 字符串引用原样,`identical()` 命中 → 复用行数。内容真的变了
  /// (新字符串)或宽度变了 → 重新排版。
  ///
  /// 为什么按索引路径区分而不是单值:一张卡片内可能有多个 Text
  /// (工具调用 = ⚙ 名称 + 参数),单值缓存会让第二个 Text 覆盖第一个,
  /// 下次渲染时第一个误命中第二个的高度。索引路径 + 字符串引用 +
  /// 宽度三元组唯一确定一次排版,互不串扰。
  final Map<(String, String, int), double> _measureCache = {};

  @override
  void didUpdateComponent(MessageCard oldComponent) {
    super.didUpdateComponent(oldComponent);
    // 组件配置变化(内容/宽度/颜色)时清空缓存,避免复用旧测量值。
    // nocterm 更新组件时保留 State 对象但不会自动重置缓存字段。
    _measureCache.clear();
  }

  @override
  Component build(BuildContext context) {
    final barChar = _barChars
        .firstWhere((c) => component.borderWidth >= c.$1,
            orElse: () => _barChars.last)
        .$2;

    // 布局阶段才构建 Row:此时拿到真实约束宽度,竖条行数精确可算。
    return LayoutBuilder(
      builder: (context, constraints) {
        final barLines =
            _calculateBarLines(component.child, constraints.maxWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 半块色块竖条:前景色 + 按行数重复的半块字符
            Text(
              List.generate(math.max(1, barLines), (_) => barChar).join('\n'),
              style: TextStyle(color: component.color),
            ),
            // padding 包内容(不在 Row 外层),竖条才能贯穿 padding 行
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: component.verticalPadding,
                ),
                child: component.child,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 竖条行数 = ceil(内容精确总高)。
  ///
  /// 内容高度由 [_measureHeight] 按实际文本宽度精确计算:文本可用宽度 =
  /// 卡片宽 - 竖条 1 列 - 水平 padding 2 列,浮点值沿链传播、最终
  /// toInt() 与 RenderText 的 `constraints.maxWidth.toInt()` 取整完全
  /// 一致。ceil 是因为竖条只能整行重复;内容高度为整数(常见情形,
  /// Text 行数 + 整数 padding)时竖条行数与卡片高度严格相等,既贯穿
  /// 全部内容又不撑高卡片。
  int _calculateBarLines(Component component, double maxWidth) {
    final textWidth = maxWidth.isFinite
        ? math.max(
            1,
            (maxWidth - _barColumnWidth - _horizontalPadding * 2).toInt(),
          )
        : _fallbackTextWidth;
    final totalHeight = _measureHeight(component, textWidth.toDouble()) +
        this.component.verticalPadding * 2;
    return math.max(1, totalHeight.ceil());
  }

  /// 精确测量子组件高度(行数,float 累积、不在中间取整)。
  ///
  /// [path] 是 Text 在卡片树中的索引路径(如 Column 第 1 个子项 → "1"),
  /// 用于多 Text 卡片时区分不同 Text 的缓存项。
  ///
  /// - [Text]:用 TextLayoutEngine 按实际文本宽度计算,配置(softWrap /
  ///   overflow / maxLines / maxWidth 取整)与 RenderText.performLayout
  ///   完全一致,结果与渲染行数严格相同;同一路径 + 同一字符串引用 +
  ///   同一宽度时命中缓存直接复用,不做排版;
  /// - [Column]:子组件高度之和;
  /// - [Padding]:累加垂直 padding,水平 padding 缩减文本可用宽度
  ///   (浮点减法链与布局的 constraints.deflate 一致);
  /// - 其他组件:1 行兜底(当前调用处只用到 Text/Column/Padding)。
  double _measureHeight(Component component, double textWidth,
      {String path = ''}) {
    if (component is Padding) {
      final horizontal = component.padding.left + component.padding.right;
      final vertical = component.padding.top + component.padding.bottom;
      final child = component.child;
      return (child == null
              ? 0.0
              : _measureHeight(child, textWidth - horizontal, path: path)) +
          vertical;
    }
    if (component is Text) {
      final width = textWidth.toInt();
      // 同一路径 + 同一字符串引用 + 同一宽度 → 命中,跳过排版(流式
      // 历史消息热路径)。identical 只认引用:内容编辑过但列表换新
      // (引用相同)时走真排版,绝不误命中内容已变的情形。
      final key = (path, component.data, width);
      final cached = _measureCache[key];
      if (cached != null) return cached;
      final result = TextLayoutEngine.layout(
        component.data,
        TextLayoutConfig(
          softWrap: component.softWrap,
          overflow: component.overflow,
          maxLines: component.maxLines,
          maxWidth: width,
        ),
      );
      _measureCache[key] = result.actualHeight.toDouble();
      return _measureCache[key]!;
    }
    if (component is Column) {
      var height = 0.0;
      for (var i = 0; i < component.children.length; i++) {
        height += _measureHeight(component.children[i], textWidth,
            path: '$path/$i');
      }
      return height;
    }
    return 1;
  }
}
