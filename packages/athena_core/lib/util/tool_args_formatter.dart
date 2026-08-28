import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';

/// Builds the content shown in the permission approval dialog for a tool the
/// Agent wants to run. The tool name itself is rendered by the dialog header,
/// so this function only produces the request payload.
///
/// Pure function (no side effects, no DI) so it can be unit-tested directly.
///
/// Security note (audit S5): for shell tools (`bash`/`powershell`) the
/// `command` argument is the only thing shown and is NOT truncated, so the
/// user always sees the complete command they are approving. A truncated
/// preview could hide a dangerous tail (e.g. `...; rm -rf ~/x`). All other
/// arguments keep a 120-character truncation to keep the dialog readable.
String formatToolArgsForApproval(String toolName, String arguments) {
  // Shell：命令是唯一的审批内容，完整展示不截断
  if (kShellToolNames.contains(toolName)) {
    try {
      final args = jsonDecode(arguments) as Map<String, dynamic>;
      final command = args['command'];
      if (command is String && command.isNotEmpty) return command;
    } catch (_) {}
    return _truncateRaw(arguments);
  }

  // 其他工具：参数键值逐行展示
  final buffer = StringBuffer();
  try {
    final args = jsonDecode(arguments) as Map<String, dynamic>;
    for (final entry in args.entries) {
      var value = entry.value.toString();
      if (value.length > 120) {
        value = '${value.substring(0, 120)}...';
      }
      buffer.writeln('${entry.key}: $value');
    }
  } catch (_) {
    buffer.write(_truncateRaw(arguments));
  }
  return buffer.toString();
}

/// 原始字符串兜底截断（200 字符）。
String _truncateRaw(String arguments) {
  if (arguments.length <= 200) return arguments;
  return '${arguments.substring(0, 200)}...';
}
