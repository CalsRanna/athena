abstract final class ByteSize {
  // 设置页展示用的短字节数格式。
  static String formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${ByteSize._trim(kb)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${ByteSize._trim(mb)} MB';
    return '${ByteSize._trim(mb / 1024)} GB';
  }

  static String _trim(double value) =>
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
