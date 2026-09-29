import 'package:logger/logger.dart';

abstract final class LoggerUtil {
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
  @override
  List<String> log(LogEvent event) {
    final level = event.level.name.toUpperCase();
    final time = event.time.toString().substring(0, 19);
    return ['[$level][$time]${event.message}'];
  }
}
