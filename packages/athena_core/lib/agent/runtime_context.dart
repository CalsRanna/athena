import 'package:athena_core/util/platform_util.dart';

/// Agent 运行环境：由前端装配层注入的运行时事实。
///
/// GUI（桌面/移动应用）与 TUI（终端）共享同一套工具集和同一份默认
/// 系统提示词，Agent 无法从提示或工具清单推断自己运行在哪个客户端，
/// 而两端的交互方式（弹窗审批 vs 终端审批、能否展示图片等）不同。
/// 装配层把该事实注入系统提示。
enum RuntimeEnvironment { gui, tui }

/// Local calendar date only; appended to the runtime context, stable within a day.
String currentDatePrompt(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return 'Current date: $year-$month-$day.';
}

/// 生成运行环境提示文本，与日期合并后作为最后一条 system 消息注入。
///
/// [workspace] 非空时额外声明本会话的工作文件夹：shell 的默认工作目录与
/// 文件工具的相对路径基准随会话变化，而工具描述是构造期的静态文本，
/// 承载不了该事实，只能在此声明。
String runtimeContextPrompt(
  RuntimeEnvironment environment, {
  String? workspace,
}) {
  final client = environment == RuntimeEnvironment.gui
      ? 'Athena GUI application'
      : 'Athena TUI (terminal)';
  final buffer = StringBuffer(
    'You are running in the $client on ${_platformName()}.\n'
    'Application data (sentinels, chats, experiences, skills) is managed '
    'through your tools — never locate, read, or modify application data '
    'files directly.',
  );
  if (workspace != null && workspace.isNotEmpty) {
    buffer.write(
      '\nYour working folder is $workspace. Shell commands run there by '
      'default, and relative paths passed to file tools resolve against it.',
    );
  }
  return buffer.toString();
}

String _platformName() {
  if (PlatformUtil.isMacOS) return 'macOS';
  if (PlatformUtil.isWindows) return 'Windows';
  if (PlatformUtil.isLinux) return 'Linux';
  if (PlatformUtil.isIOS) return 'iOS';
  if (PlatformUtil.isAndroid) return 'Android';
  return 'an unknown platform';
}
