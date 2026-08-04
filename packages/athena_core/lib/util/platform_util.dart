import 'dart:io';

/// Single source of truth for platform detection.
///
/// Prefer [isDesktop] and [isMobile] over raw [Platform] checks.
/// Use individual [isWindows], [isMacOS], [isLinux], [isIOS], [isAndroid]
/// for OS-specific behavior.
class PlatformUtil {
  PlatformUtil._();

  /// True on macOS, Linux, or Windows.
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// True on iOS or Android.
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;

  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
}
