import 'package:athena_core/entity/model_entity.dart';

/// 模型行的副标题：`Released 2026-09-10 · 1M context · $0.15/M in · $0.6/M out`。
///
/// 没有任何可显示项时返回 null（行就不画说明）。
String? modelSubtitle(ModelEntity model) {
  var parts = <String>[
    if (model.releasedAt.isNotEmpty) model.releasedAt,
    if (model.contextWindow > 0) '${compactTokens(model.contextWindow)} context',
    if (model.inputPrice.isNotEmpty) '${pricePerMillion(model.inputPrice)} in',
    if (model.outputPrice.isNotEmpty)
      '${pricePerMillion(model.outputPrice)} out',
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// 把价格字段压成 `$0.15/M`。
///
/// 新数据本身就是 `$0.15/M`；旧缓存写成 `$0.15/M input tokens`（输出价也
/// 曾被写成 input），这里只取前面的数值部分，方向由调用方标注。
/// 用户手填的自由文本原样返回。
String pricePerMillion(String raw) {
  final match = RegExp(r'^\$?\d+(?:\.\d+)?/M').firstMatch(raw.trim());
  if (match == null) return raw.trim();
  final value = match.group(0)!;
  return value.startsWith(r'$') ? value : '\$$value';
}

/// 上下文窗口的紧凑写法：1,000,000 → `1M`，131,072 → `128K`，200,000 → `200K`。
///
/// 只用于展示；编辑框里仍用 `formatContextWindow` 的精确值。
String compactTokens(int tokens) {
  if (tokens >= 1000000) {
    final m = tokens / 1000000;
    final text = m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1);
    return '${text}M';
  }
  if (tokens >= 1000) {
    final k = tokens / 1024;
    // 128K（131072）这类二进制档位取整；十进制档位（200,000）同样四舍五入
    return '${k.round()}K';
  }
  return tokens.toString();
}
