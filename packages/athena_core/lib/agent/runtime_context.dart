import 'package:athena_core/util/platform_util.dart';

/// Agent 运行环境：由前端装配层注入的运行时事实。
///
/// GUI（桌面/移动应用）与 TUI（终端）共享同一套工具集和同一份默认
/// 系统提示词，Agent 无法从提示或工具清单推断自己运行在哪个客户端，
/// 而两端的应用数据存储完全不同（GUI: SQLite；TUI: `~/.athena/tui/`
/// JSON 文件）。装配层把该事实注入系统提示，避免 Agent 在文件系统里
/// 猜测应用数据的存储位置。
enum RuntimeEnvironment { gui, tui }

/// 生成运行时上下文提示文本，注入在 sentinel 系统提示之后。
String runtimeContextPrompt(RuntimeEnvironment environment) {
  final client = environment == RuntimeEnvironment.gui
      ? 'Athena GUI application'
      : 'Athena TUI (terminal)';
  return 'You are running in the $client on ${_platformName()}.\n'
      'Application data (sentinels, chats, experiences, skills) is managed '
      'through your tools — never locate, read, or modify application data '
      'files directly.';
}

String _platformName() {
  if (PlatformUtil.isMacOS) return 'macOS';
  if (PlatformUtil.isWindows) return 'Windows';
  if (PlatformUtil.isLinux) return 'Linux';
  if (PlatformUtil.isIOS) return 'iOS';
  if (PlatformUtil.isAndroid) return 'Android';
  return 'an unknown platform';
}
