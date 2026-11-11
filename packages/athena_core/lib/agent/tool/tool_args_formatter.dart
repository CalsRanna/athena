import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

abstract final class ToolArgsFormatter {
  /// Optional model-authored intent; never used to decide permission or execution.
  static String? toolCallDescription(String arguments) =>
      ToolArgsFormatter._callDescription(
        ToolArgsFormatter._decodeArgs(arguments),
      );

  static String? _callDescription(Map<String, dynamic>? args) {
    final description = args?[ToolArguments.toolCallDescriptionKey];
    if (description is! String || description.trim().isEmpty) return null;
    return description.trim();
  }

  /// Single-line preview for tool cards. Approval details use the full payload.
  static String toolArgPreview(String toolName, String arguments) {
    final args = ToolArgsFormatter._decodeArgs(arguments);
    if (args == null) return ToolArgsFormatter._preview(arguments);

    final description = ToolArgsFormatter._callDescription(args);
    if (description != null) return ToolArgsFormatter._preview(description);

    final keyField = switch (toolName) {
      _ when PermissionRule.kShellToolNames.contains(toolName) => 'command',
      _ when PermissionRule.kFileToolNames.contains(toolName) => 'path',
      'web_fetch' => 'url',
      'web_search' => 'query',
      _ => null,
    };
    final value = args[keyField];
    if (value is String && value.trim().isNotEmpty) {
      return ToolArgsFormatter._preview(value);
    }
    args.remove(ToolArguments.toolCallDescriptionKey);
    return ToolArgsFormatter._preview(jsonEncode(args));
  }

  /// Actual arguments for approval, with display metadata omitted.
  ///
  /// Values are never truncated: callers provide scrolling so the user can inspect
  /// the complete command, working directory, file content, or request payload.
  static String formatToolArgsForApproval(String toolName, String arguments) {
    final args = ToolArgsFormatter._decodeArgs(arguments);
    if (args == null) return arguments;
    args.remove(ToolArguments.toolCallDescriptionKey);

    final lines = <String>[];
    if (PermissionRule.kShellToolNames.contains(toolName)) {
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

  static Map<String, dynamic>? _decodeArgs(String arguments) {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      // Streaming arguments may not yet contain a complete JSON object.
      return null;
    }
  }

  static String _preview(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final characters = text.runes;
    if (characters.length <= 200) return text;
    return String.fromCharCodes(characters.take(200));
  }
}
