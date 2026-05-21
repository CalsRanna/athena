import 'package:athena/agent/tool/tool_interface.dart';

enum PermissionChoice { allowOnce, allowSession, deny }

class PermissionService {
  final Map<String, PermissionChoice> _sessionCache = {};

  /// Returns null if the tool can auto-run.
  /// Returns PermissionChoice.deny if forbidden.
  /// Returns non-null if needs approval (handled by UI callback).
  PermissionChoice? check({
    required Tool tool,
    required Map<String, dynamic> args,
    String? skillAllowedTools,
  }) {
    if (tool.dangerLevel == DangerLevel.forbidden) {
      return PermissionChoice.deny;
    }

    if (tool.dangerLevel == DangerLevel.safe) {
      return null;
    }

    if (skillAllowedTools != null) {
      final allowed = _parseAllowedTools(skillAllowedTools);
      if (allowed.any((a) => _matchesTool(a, tool.name, args))) {
        return null;
      }
    }

    final key = _cacheKey(tool, args);
    final cached = _sessionCache[key];
    if (cached == PermissionChoice.allowSession) return null;

    return PermissionChoice.allowOnce;
  }

  void rememberChoice({
    required Tool tool,
    required Map<String, dynamic> args,
    required PermissionChoice choice,
  }) {
    final key = _cacheKey(tool, args);
    _sessionCache[key] = choice;
  }

  void clearSessionCache() {
    _sessionCache.clear();
  }

  String _cacheKey(Tool tool, Map<String, dynamic> args) {
    final arg = args.containsKey('command')
        ? args['command']
        : args['path'] ?? '';
    return '${tool.name}:$arg';
  }

  List<String> _parseAllowedTools(String allowedTools) {
    return allowedTools
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _matchesTool(String pattern, String toolName, Map<String, dynamic> args) {
    if (pattern.startsWith('Bash(')) {
      if (toolName != 'shell' && toolName != 'bash') return false;
      final inner = pattern.substring(5, pattern.length - 1).trim();
      final command = args['command'] as String? ?? '';
      return _matchBashPattern(inner, command);
    }
    return pattern == toolName;
  }

  bool _matchBashPattern(String pattern, String command) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return command.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return command == pattern;
  }
}
