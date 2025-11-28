import 'dart:convert';

extension JsonMapExtension on Map<String, dynamic> {
  String getString(String key, {String defaultValue = ''}) {
    final value = this[key];
    if (value == null) return defaultValue;
    return value as String;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final value = this[key];
    if (value == null) return defaultValue;
    return value as int;
  }

  int? getIntOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    return value as int;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return value as double;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    return defaultValue;
  }

  DateTime getDateTime(String key, {DateTime? defaultValue}) {
    final value = this[key];
    if (value == null) return defaultValue ?? DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(value as int);
  }

  DateTime? getDateTimeOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value as int);
  }

  List<T> getList<T>(String key) {
    final value = this[key];
    if (value == null) return [];
    if (value is String) {
      if (value.isEmpty) return [];
      try {
        return List<T>.from(jsonDecode(value));
      } catch (e) {
        return [];
      }
    }
    if (value is List) {
      return List<T>.from(value);
    }
    return [];
  }

  Map<K, V> getMap<K, V>(String key) {
    final value = this[key];
    if (value == null) return {};
    if (value is String) {
      if (value.isEmpty) return {};
      try {
        return Map<K, V>.from(jsonDecode(value));
      } catch (e) {
        return {};
      }
    }
    if (value is Map) {
      return Map<K, V>.from(value);
    }
    return {};
  }
}
