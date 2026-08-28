import 'package:logger/logger.dart';

class LoggerUtil {
  static final _logger = Logger(printer: PlainPrinter());

  static void d(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.d(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.i(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(message, time: time, error: error, stackTrace: stackTrace);
  }
}

class PlainPrinter extends LogPrinter {
  String getTrace(LogEvent event) {
    final stackTrace = event.stackTrace ?? StackTrace.current;
    final traces = stackTrace.toString().split('\n');
    final exactTrace = traces.where(_excludePrinter).first;
    final match = RegExp(r'\(([^)]+)\)').firstMatch(exactTrace);
    if (match == null) return 'Unknown';
    // match[0] 形如 "(package:foo/bar.dart:12:34)"：
    // 去掉首尾括号，并剥掉 package: 前缀（native/dart: 路径原样保留）。
    final raw = match[0]!;
    return raw.substring(1, raw.length - 1).replaceFirst('package:', '');
  }

  bool _excludePrinter(String trace) {
    return !trace.contains('Printer') && !trace.contains('Logger');
  }

  @override
  List<String> log(LogEvent event) {
    final level = event.level.name.toUpperCase();
    final trace = getTrace(event);
    final time = event.time.toString().substring(0, 19);
    return ['[$level][$trace][$time] ${event.message}'];
  }
}
