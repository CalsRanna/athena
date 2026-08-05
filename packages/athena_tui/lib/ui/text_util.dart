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

/// 剥离 ANSI 转义序列与危险控制字符，用于**渲染层**清洗不可信文本
/// （模型输出、工具结果、权限参数等）。
///
/// 保留 `\n` / `\t` / `\r`（布局需要），剥离：
/// - ESC 及其后的 CSI 序列（`ESC [ ... final-byte`，清屏/光标移动/颜色）
/// - OSC 序列（`ESC ] ... BEL|ST`，可篡改终端标题、覆写剪贴板 OSC 52）
/// - 其余 C0 控制字符（BEL、BS 等）与其他 ESC 序列
///
/// 只在渲染入口应用，不破坏存储原文（ChatController 层不调用）。
String sanitizeAnsi(String text) {
  if (text.isEmpty) return text;
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x1B) {
      // ESC 序列：跳过 ESC 及后续参数/中间字节，直到最终字节或结束。
      i = _skipEscapeSequence(text, i);
      continue;
    }
    if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) {
      i++; // 剥离 C0 控制字符（保留 \t \n \r）
      continue;
    }
    if (c == 0x7F) {
      i++; // DEL
      continue;
    }
    out.writeCharCode(c);
    i++;
  }
  return out.toString();
}

/// 跳过从 [start]（指向 ESC）开始的转义序列，返回下一个应处理的索引。
///
/// - CSI：`ESC [` 后跟 0x30-0x3F 参数字节与 0x20-0x2F 中间字节，
///   最终字节 0x40-0x7E
/// - OSC：`ESC ]` 后跟任意字节直到 BEL(0x07) 或 ST(ESC \)
/// - 其他两字节序列：`ESC` + 单个字符
int _skipEscapeSequence(String text, int start) {
  final n = text.length;
  var i = start + 1;
  if (i >= n) return n;

  // CSI：ESC [
  if (text.codeUnitAt(i) == 0x5B) {
    i++;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (c >= 0x40 && c <= 0x7E) return i + 1; // 最终字节
      i++;
    }
    return n;
  }

  // OSC：ESC ] ... 直到 BEL 或 ST（ESC \）
  if (text.codeUnitAt(i) == 0x5D) {
    i++;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (c == 0x07) return i + 1; // BEL
      if (c == 0x1B) {
        // ST = ESC \；孤立的 ESC 之后继续扫到 ESC \ 或文本结束
        if (i + 1 < n && text.codeUnitAt(i + 1) == 0x5C) return i + 2;
        i++;
        continue;
      }
      i++;
    }
    return n;
  }

  // 其他：ESC + 单字符（或序列末）
  return i + 1;
}
