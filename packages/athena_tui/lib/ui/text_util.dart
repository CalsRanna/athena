/// 文本截断:超长时保留内容使**总长不超过 [max]**(含 [suffix])。
///
/// 与各组件原有的私有 `_truncate(text, max)` 语义一致:
/// 结果长度 = min(原文长度, max)。
String truncateText(String text, int max, {String suffix = '…'}) {
  if (text.length <= max) return text;
  final keep = max - suffix.length;
  if (keep <= 0) return suffix.substring(0, max);
  return '${text.substring(0, keep)}$suffix';
}
