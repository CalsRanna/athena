import 'package:athena/agent/permission/permission_rule.dart';

/// 权限编排：
/// - 检查用户持久化规则 → 命中则自动放行
/// - 无匹配 → 需要弹出审批弹窗（由调用方处理）
class PermissionService {
  final PermissionStore _store;

  PermissionService({required PermissionStore store})
      : _store = store;

  /// 检查工具调用是否需要弹窗。
  /// - `true`  → 规则命中，自动允许，无需弹窗
  /// - `null`  → 需要弹出审批弹窗
  bool? check(String toolName, Map<String, dynamic> args) {
    final keyArg = _primaryArg(toolName, args);

    for (final rule in _store.rules) {
      if (rule.matches(toolName, keyArg)) return true;
    }

    return null;
  }

  /// 持久化一条规则。
  Future<void> persistRule(PermissionRule rule) => _store.add(rule);

  /// 加载已持久化规则。
  Future<void> load() => _store.load();

  /// 提取工具调用的关键参数，归一化后用于规则匹配。
  String? primaryArg(String toolName, Map<String, dynamic> args) {
    return _primaryArg(toolName, args);
  }

  /// 生成"始终允许" checkbox 的描述文案。
  String describeRule(String toolName) {
    return switch (toolName) {
      'bash' || 'powershell' => 'Always allow this command pattern',
      'file_read' => 'Always allow reads matching this path',
      'file_write' || 'file_update' => 'Always allow writes matching this path',
      'web_fetch' => 'Always allow this domain',
      _ => 'Always allow $toolName',
    };
  }

  String? _primaryArg(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'bash':
      case 'powershell':
        return args['command'] as String?;
      case 'file_read':
      case 'file_write':
      case 'file_update':
        return args['path'] as String?;
      case 'web_fetch':
        final url = args['url'] as String?;
        if (url == null) return null;
        final uri = Uri.tryParse(url);
        if (uri == null || uri.host.isEmpty) return null;
        if (uri.scheme != 'http' && uri.scheme != 'https') return null;
        return uri.origin;
      default:
        return null;
    }
  }
}
