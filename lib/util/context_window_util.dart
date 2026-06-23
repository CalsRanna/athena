/// Context-window 文本/数值解析与格式化工具。
///
/// 历史：models.context_window 曾经是 TEXT 列，存储形如 "64K context"、
/// "200,000 context"、"128K" 的自由文本。现已迁移为 INTEGER（单位 token）。
/// 本 util 保留解析函数，仅供历史路径兼容，以及把整数格式化为
/// "64K" / "1M" 的简洁展示。

/// 把旧 context_window 文本解析为 token 数。
/// 支持："200,000 context"、"64K context"、"128K"、"1M"、纯粹千分位数字。
/// 解析失败回退 0。
int parseContextWindow(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return 0;
  // 去掉尾部的 " context" 之类说明性后缀
  s = s.replaceAll(RegExp(r'\s*context$', caseSensitive: false), '').trim();
  if (s.isEmpty) return 0;
  // 检测尾部 K/M（大小写不敏感）后缀
  var suffixMatch = RegExp(r'^([0-9.,]+)\s*([kKmM])$').firstMatch(s);
  if (suffixMatch != null) {
    var digits = suffixMatch.group(1)!.replaceAll(',', '');
    var mult = suffixMatch.group(2)!.toLowerCase() == 'k' ? 1024 : 1024 * 1024;
    var n = int.tryParse(digits);
    if (n == null) return 0;
    return n * mult;
  }
  // 纯数字（含千分位）
  var digits = s.replaceAll(',', '');
  return int.tryParse(digits) ?? 0;
}

/// 把 token 数格式化为简洁字符串：≥1M 显示"M"，≥1024 显示"K"，否则原值。
String formatContextWindow(int tokens) {
  if (tokens >= 1024 * 1024 && tokens % (1024 * 1024) == 0) {
    return '${tokens ~/ (1024 * 1024)}M';
  }
  if (tokens >= 1024 && tokens % 1024 == 0) {
    return '${tokens ~/ 1024}K';
  }
  if (tokens >= 1000) {
    // 千分位展示，保持可读
    var s = tokens.toString();
    var buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
  return tokens.toString();
}