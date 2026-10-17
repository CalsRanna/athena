// 设置页展示用的短字节数格式。
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${_trim(kb)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${_trim(mb)} MB';
  return '${_trim(mb / 1024)} GB';
}

String _trim(double value) =>
    value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
