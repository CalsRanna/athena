import 'dart:convert';

/// Builds the human-readable preview shown in the permission approval dialog
/// for a tool the Agent wants to run.
///
/// Pure function (no side effects, no DI) so it can be unit-tested directly.
///
/// Security note (audit S5): for shell tools (`bash`/`powershell`) the
/// `command` argument is shown IN FULL with no truncation, so the user always
/// sees the complete command they are approving. A truncated preview could
/// hide a dangerous tail (e.g. `...; rm -rf ~/x`). All other arguments keep a
/// 120-character truncation to keep the dialog readable.
String formatToolArgsForApproval(String toolName, String arguments) {
  final buffer = StringBuffer();
  buffer.writeln('Agent wants to use: $toolName');
  final isShellTool = toolName == 'bash' || toolName == 'powershell';
  try {
    final args = jsonDecode(arguments) as Map<String, dynamic>;
    for (final entry in args.entries) {
      var value = entry.value.toString();
      final showFull = isShellTool && entry.key == 'command';
      if (!showFull && value.length > 120) {
        value = '${value.substring(0, 120)}...';
      }
      buffer.writeln('  ${entry.key}: $value');
    }
  } catch (_) {
    if (arguments.length > 200) {
      buffer.writeln('  ${arguments.substring(0, 200)}...');
    } else {
      buffer.writeln('  $arguments');
    }
  }
  return buffer.toString();
}
