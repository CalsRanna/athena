/// A Dart extension on the DateTime class that provides a human-readable
/// representation of a date and time.
extension HumanReadableDateTime on DateTime {
  /// Returns a human-readable string representation of the date and time.
  /// The string returned depends on the difference between the current time
  /// and the time represented by this DateTime instance.
  ///
  /// If the difference is less than one day, the string returned is in the
  /// format "HH:MM", where HH is the hour and MM is the minute.
  ///
  /// If the difference is exactly one day, the string returned is "昨天
  /// HH:MM".
  ///
  /// If the difference is exactly two days, the string returned is "前天
  /// HH:MM".
  ///
  /// If the difference is less than one week, the string returned is the name
  /// of the day of the week in Chinese characters, e.g. "星期一".
  ///
  /// If the difference is less than one year, the string returned is in the
  /// format "$month月$day日", where $month is the month and $day is the day of
  /// the month.
  ///
  /// If the difference is one year or more, the string returned is in the
  /// format "$year年$month月$day日", where $year is the year, $month is the
  /// month, and $day is the day of the month.
  String toHumanReadableString() {
    final now = DateTime.now();
    final difference = now.difference(this);
    if (difference.inDays == 0) {
      return _hourAndMinute;
    } else if (difference.inDays == 1) {
      return '昨天 $_hourAndMinute';
    } else if (difference.inDays == 2) {
      return '前天 $_hourAndMinute';
    } else if (difference.inDays < 7) {
      return '星期${['一', '二', '三', '四', '五', '六', '日'][weekday - 1]}';
    } else if (difference.inDays < 365) {
      return '$month月$day日';
    } else {
      return '$year年$month月$day日';
    }
  }

  /// Returns a string representation of the hour and minute of the date and
  /// time in the format "HH:MM".
  String get _hourAndMinute {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
