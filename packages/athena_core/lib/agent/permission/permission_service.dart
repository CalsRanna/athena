import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 权限编排(三层判定):
/// 1. readOnly 短路:只读工具/只读命令默认放行,永不弹窗
/// 2. 会话级缓存:当前 run 内已批准的动作直接放行
/// 3. 持久规则:命中则自动放行;未命中 → 需要弹窗(由调用方处理)
class PermissionService {
  final PermissionStore _store;
  final Map<String, bool> _sessionApprovals = {};

  PermissionService({required PermissionStore store}) : _store = store;

  /// 检查工具调用是否需要弹窗。
  ///
  /// - `true`  → 放行(只读 / 会话级命中 / 规则命中),无需弹窗
  /// - `null`  → 需要弹出审批弹窗
  ///
  /// [risk] 为工具的危险等级(由调用方从 ToolRegistry 查询);
  /// 只读工具或只读 shell 命令直接放行。
  bool? check(
    String toolName,
    Map<String, dynamic> args, {
    ToolRisk? risk,
  }) {
    // ① readOnly 短路:只读工具永不弹窗
    if (risk == ToolRisk.readOnly) return true;

    // 只读 shell 命令(ls、git status...)也不弹窗
    if (_isShellTool(toolName)) {
      final command = args['command'] as String?;
      if (command != null && CommandAnalyzer.isReadOnlyCommand(command)) {
        return true;
      }
    }

    // ② 会话级缓存:当前 run 内已批准的动作直接放行
    final sessionKey = _sessionKey(toolName, args);
    if (sessionKey != null && _sessionApprovals[sessionKey] == true) {
      return true;
    }

    // ③ 持久规则:命中则放行
    if (_ruleMatched(toolName, args)) return true;

    return null;
  }

  /// 记录一次会话级放行(弹窗批准后调用)。
  Future<void> approveForSession(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final key = _sessionKey(toolName, args);
    if (key != null) _sessionApprovals[key] = true;
  }

  /// 清空会话级缓存(agent run 开始/结束时调用)。
  void resetSession() {
    _sessionApprovals.clear();
  }

  /// 持久化一条规则。
  Future<void> persistRule(PermissionRule rule) => _store.add(rule);

  /// 加载已持久化规则。
  Future<void> load() => _store.load();

  /// 提取工具调用的关键参数,归一化后用于规则匹配。
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

  bool _ruleMatched(String toolName, Map<String, dynamic> args) {
    final keyArg = _primaryArg(toolName, args);
    // shell 工具解析动作,用于动作级规则匹配
    final action = _isShellTool(toolName)
        ? CommandAnalyzer.extractAction(keyArg ?? '')
        : null;

    for (final rule in _store.rules) {
      if (rule.matches(toolName, keyArg, action: action)) return true;
    }
    return false;
  }

  static bool _isShellTool(String toolName) =>
      toolName == 'bash' || toolName == 'powershell';

  /// 会话级缓存 key:
  /// - shell:按动作缓存(git status 批准 → git status -s 也放行,git push 不放行)
  /// - 其他:按 toolName + keyArg 精确缓存
  String? _sessionKey(String toolName, Map<String, dynamic> args) {
    final keyArg = _primaryArg(toolName, args);
    if (_isShellTool(toolName)) {
      final action = CommandAnalyzer.extractAction(keyArg ?? '');
      if (action != null) return 'shell:$action';
      return keyArg == null ? null : 'shell:$keyArg';
    }
    return keyArg == null ? null : '$toolName:$keyArg';
  }

  String? _primaryArg(String toolName, Map<String, dynamic> args) {
    // 文件工具集合统一来自 kFileToolNames,避免多处硬编码不一致
    if (kFileToolNames.contains(toolName)) return args['path'] as String?;
    switch (toolName) {
      case 'bash':
      case 'powershell':
        return args['command'] as String?;
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
