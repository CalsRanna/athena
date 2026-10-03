import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/logger_util.dart';

/// Permission gate result before applying the run's approval mode.
enum PermissionVerdict { prompt, deny }

/// 持久禁令与本轮用户拒绝优先于三种审批模式。
/// 批准仅用于当次调用，不缓存，不生成持久 allow 规则。
class PermissionService {
  PermissionService({required PermissionStore store}) : _store = store;

  final PermissionStore _store;
  final Map<int, Set<String>> _sessionDenials = {};

  PermissionVerdict check(
    int runId,
    String toolName,
    Map<String, dynamic> args,
  ) {
    _store.refreshIfChanged();
    final keyArg = _primaryArg(toolName, args) ?? '';
    for (final rule in _store.rules) {
      try {
        if (rule.matches(toolName, keyArg)) return PermissionVerdict.deny;
      } catch (error) {
        LoggerUtil.w('Permission rule skipped (${rule.toJson()}): $error');
      }
    }
    if (_sessionDenials[runId]?.contains(_sessionKey(toolName, args)) ??
        false) {
      return PermissionVerdict.deny;
    }
    return PermissionVerdict.prompt;
  }

  /// A user denial blocks retries of this exact call in the same run.
  void denyForSession(int runId, String toolName, Map<String, dynamic> args) {
    (_sessionDenials[runId] ??= {}).add(_sessionKey(toolName, args));
  }

  void resetSession(int runId) => _sessionDenials.remove(runId);

  Future<void> load() => _store.load();

  String _sessionKey(String toolName, Map<String, dynamic> args) =>
      jsonEncode([toolName, _sortedJson(toolExecutionArguments(args))]);

  Object? _sortedJson(Object? value) {
    if (value is Map<String, dynamic>) {
      return {
        for (final key in value.keys.toList()..sort())
          key: _sortedJson(value[key]),
      };
    }
    if (value is List) return value.map(_sortedJson).toList();
    return value;
  }

  String? _primaryArg(String toolName, Map<String, dynamic> args) {
    if (kFileToolNames.contains(toolName)) return args['path'] as String?;
    if (kShellToolNames.contains(toolName)) return args['command'] as String?;
    if (toolName != 'web_fetch') return null;
    final url = args['url'] as String?;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.origin;
  }
}
