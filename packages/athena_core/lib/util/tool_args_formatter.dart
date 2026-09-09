import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// Optional model-authored intent; never used to decide permission or execution.
String? toolCallDescription(String arguments) =>
    _callDescription(_decodeArgs(arguments));

String? _callDescription(Map<String, dynamic>? args) {
  final description = args?[toolCallDescriptionKey];
  if (description is! String || description.trim().isEmpty) return null;
  return description.trim();
}

/// Single-line preview for tool cards. Approval details use the full payload.
String toolArgPreview(String toolName, String arguments) {
  final args = _decodeArgs(arguments);
  if (args == null) return _preview(arguments);

  final description = _callDescription(args);
  if (description != null) return _preview(description);

  final keyField = switch (toolName) {
    _ when kShellToolNames.contains(toolName) => 'command',
    _ when kFileToolNames.contains(toolName) => 'path',
    'web_fetch' => 'url',
    'web_search' => 'query',
    _ => null,
  };
  final value = args[keyField];
  if (value is String && value.trim().isNotEmpty) return _preview(value);
  args.remove(toolCallDescriptionKey);
  return _preview(jsonEncode(args));
}

/// Actual arguments for approval, with display metadata omitted.
///
/// Values are never truncated: callers provide scrolling so the user can inspect
/// the complete command, working directory, file content, or request payload.
String formatToolArgsForApproval(String toolName, String arguments) {
  final args = _decodeArgs(arguments);
  if (args == null) return arguments;
  args.remove(toolCallDescriptionKey);

  final lines = <String>[];
  if (kShellToolNames.contains(toolName)) {
    final command = args['command'];
    if (command is String && command.isNotEmpty) {
      lines.add(command);
      args.remove('command');
    }
  }

  for (final entry in args.entries) {
    final value = entry.value is String
        ? entry.value as String
        : const JsonEncoder.withIndent('  ').convert(entry.value);
    lines.add('${entry.key}: $value');
  }
  return lines.join('\n');
}

Map<String, dynamic>? _decodeArgs(String arguments) {
  try {
    return jsonDecode(arguments) as Map<String, dynamic>;
  } catch (_) {
    // Streaming arguments may not yet contain a complete JSON object.
    return null;
  }
}

String _preview(String value) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final characters = text.runes;
  if (characters.length <= 200) return text;
  return '${String.fromCharCodes(characters.take(200))}…';
}
