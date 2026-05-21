import 'package:athena/agent/permission/permission_rule.dart';

class PermissionService {
  final PermissionStore _store;

  PermissionService({required PermissionStore store}) : _store = store;

  /// 返回: true=自动允许, null=需要弹窗
  bool? check(String toolName, Map<String, dynamic> args) {
    final keyArg = _extractKeyArg(toolName, args);

    if (_matchesAllowRules(toolName, keyArg)) {
      if (_matchesDenyRules(toolName, keyArg)) return null;
      return true;
    }

    return null;
  }

  /// 是否命中 deny 规则（命中则隐藏 checkbox）
  bool isDangerous(String toolName, Map<String, dynamic> args) {
    final keyArg = _extractKeyArg(toolName, args);
    return _matchesDenyRules(toolName, keyArg);
  }

  /// 根据工具调用自动生成 allow 规则
  PermissionRule generateRule(String toolName, Map<String, dynamic> args) {
    final keyArg = _extractKeyArg(toolName, args);
    switch (toolName) {
      case 'shell':
        final prefix = _extractCommandPrefix(keyArg ?? '');
        return PermissionRule(tool: toolName, prefix: prefix);
      case 'file_write':
      case 'file_update':
      case 'file_delete':
        final dir = _extractDirectory(keyArg ?? '');
        return PermissionRule(tool: toolName, prefix: dir);
      default:
        return PermissionRule(tool: toolName);
    }
  }

  /// 生成 checkbox 显示文案
  String generateRuleDescription(String toolName, Map<String, dynamic> args) {
    final rule = generateRule(toolName, args);
    if (rule.prefix == null) {
      return 'Always allow $toolName';
    }
    switch (toolName) {
      case 'shell':
        final cmd = rule.prefix!.trim();
        return 'Always allow "$cmd" commands';
      case 'file_write':
      case 'file_update':
        return 'Always allow writes to "${rule.prefix}"';
      case 'file_delete':
        return 'Always allow deletes in "${rule.prefix}"';
      default:
        return 'Always allow $toolName with prefix "${rule.prefix}"';
    }
  }

  /// 持久化规则
  Future<void> persistRule(PermissionRule rule) async {
    await _store.addAllowRule(rule);
  }

  /// 加载规则
  Future<void> load() async {
    await _store.load();
  }

  bool _matchesAllowRules(String toolName, String? keyArg) {
    return _store.allowRules.any((r) => r.matchesAllow(toolName, keyArg));
  }

  bool _matchesDenyRules(String toolName, String? keyArg) {
    return _store.allDenyRules.any((r) => r.matchesDeny(toolName, keyArg));
  }

  String? _extractKeyArg(String toolName, Map<String, dynamic> args) {
    return switch (toolName) {
      'shell' => args['command'] as String?,
      'file_write' || 'file_update' || 'file_delete' => args['path'] as String?,
      'web_fetch' => args['url'] as String?,
      _ => null,
    };
  }

  String _extractCommandPrefix(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    return '${parts.first} ';
  }

  String _extractDirectory(String path) {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return '${path.substring(0, lastSlash + 1)}';
  }
}
