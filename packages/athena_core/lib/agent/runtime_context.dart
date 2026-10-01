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
  return '当前日期：$year-$month-$day。';
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
      ? 'Athena 图形界面应用'
      : 'Athena 终端界面（TUI）';
  final buffer = StringBuffer(
    '你正在 ${_platformName()} 上的 $client 中运行。\n'
    '应用数据（角色、会话、经验、技能）由工具管理，'
    '绝不要直接定位、读取或修改应用数据文件。',
  );
  if (workspace != null && workspace.isNotEmpty) {
    buffer.write(
      '\n你的工作文件夹是 $workspace。Shell 命令默认在此运行，'
      '文件工具的相对路径也以此为基准解析。',
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
  return '未知平台';
}
