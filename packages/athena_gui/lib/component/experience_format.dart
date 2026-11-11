/// 经验页共用的日期展示格式。
abstract final class ExperienceFormat {
  static String date(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
  }
}
