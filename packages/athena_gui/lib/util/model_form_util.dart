/// 模型表单里 `Released` 与价格的文本格式转换。
///
/// 实体存的是展示文本（`Released 2026-09-10`、`$0.15/M`），编辑框只放用户
/// 能直接改的裸值；两个平台的模型表单共用这一套转换，避免一边改了另一边漏掉。
library;

/// `Released 2026-09-10` → `2026-09-10`（编辑框里只放日期）。
String stripModelReleasedAt(String raw) {
  return raw.replaceFirst(RegExp(r'^Released\s+'), '').trim();
}

/// `$0.15/M input tokens` / `$0.15/M` → `0.15`；自由文本原样保留。
String stripModelPrice(String raw) {
  final match = RegExp(r'^\$?(\d+(?:\.\d+)?)/M').firstMatch(raw.trim());
  return match?.group(1) ?? raw.trim();
}

/// `0.15` → `$0.15/M`；空串留空；非数字原样保存（用户自己的写法）。
String formatModelPrice(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final value = double.tryParse(text.replaceFirst(r'$', ''));
  if (value == null) return text;
  var s = value.toStringAsFixed(4);
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');
  return '\$$s/M';
}
