/// YAML 标量编码：把任意值写成**始终带双引号**的字符串字面量。
///
/// 手写 YAML 而不是用 `yaml` 包的写入端，是为了让生成的配置保持人能读、
/// 能手改的形态（与 GUI 展示的口径一致）。
///
/// 双引号不是风格选择：不加引号的标量会被 YAML 解析成 int / bool / null /
/// 日期，读回时类型不符会让整个配置项丢失——纯数字的 API key 会变成 int，
/// `'true'` 会变成 bool，`'null'` 会变成 null，UUID 之外的纯数字 id 同理。
/// 引号还能让冒号、井号、前后空格这些在标量里有语法含义的字符不需要额外判断。
abstract final class YamlScalarCodec {
  static String encode(Object? value) {
    if (value == null) return '""';
    // bool 与数字原样写出:它们没有「被 YAML 误解析」的风险,加了引号反而
    // 会让 `enabled: "false"` 读回成字符串,`is bool` 判断失败后字段丢失。
    if (value is bool || value is num) return value.toString();
    final s = value.toString();
    if (s.isEmpty) return '""';
    final buf = StringBuffer('"');
    for (final unit in s.codeUnits) {
      if (unit == 0x5C) {
        buf.write(r'\\');
      } else if (unit == 0x22) {
        buf.write(r'\"');
      } else if (unit == 0x0A) {
        buf.write(r'\n');
      } else if (unit == 0x09) {
        buf.write(r'\t');
      } else if (unit == 0x0D) {
        buf.write(r'\r');
      } else if (unit < 0x20) {
        buf.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
      } else {
        buf.writeCharCode(unit);
      }
    }
    buf.write('"');
    return buf.toString();
  }
}
