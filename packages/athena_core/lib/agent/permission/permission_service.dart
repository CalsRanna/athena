import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 权限编排(三层判定):
/// 1. readOnly 短路:只读工具/只读命令默认放行,永不弹窗
/// 2. 会话级缓存:当前 run 内已批准的动作直接放行
/// 3. 持久规则:命中则自动放行;未命中 → 需要弹窗(由调用方处理)
///
/// 会话级缓存按 [runId] 隔离:多个 Agent 并发运行时,
/// A 任务批准的命令不会被 B 任务自动放行。
class PermissionService {
  final PermissionStore _store;
  final Map<int, Map<String, bool>> _sessionApprovals = {};

  PermissionService({required PermissionStore store}) : _store = store;

  /// 检查工具调用是否需要弹窗。
  ///
  /// - `true`  → 放行(只读 / 会话级命中 / 规则命中),无需弹窗
  /// - `null`  → 需要弹出审批弹窗
  ///
  /// [runId] 为本次 Agent run 的标识(会话级缓存按 run 隔离);
  /// [risk] 为工具的危险等级(由调用方从 ToolRegistry 查询);
  /// 只读工具或只读 shell 命令直接放行。
  bool? check(
    int runId,
    String toolName,
    Map<String, dynamic> args, {
    ToolRisk? risk,
  }) {
    // ① readOnly 短路:只读工具永不弹窗
    // 例外:web_fetch 的 POST / 自定义 headers 可驱动内网接口,需弹窗
    if (risk == ToolRisk.readOnly && !_readOnlyOverride(toolName, args)) {
      return true;
    }

    // 只读 shell 命令(ls、git status...)也不弹窗
    if (_isShellTool(toolName)) {
      final command = args['command'] as String?;
      if (command != null && CommandAnalyzer.isReadOnlyCommand(command)) {
        return true;
      }
    }

    // ② 会话级缓存:当前 run 内已批准的动作直接放行
    final sessionKey = _sessionKey(toolName, args);
    if (sessionKey != null &&
        _sessionApprovals[runId]?[sessionKey] == true) {
      return true;
    }

    // ③ 持久规则:命中则放行
    if (_ruleMatched(toolName, args)) return true;

    return null;
  }

  /// 记录一次会话级放行(弹窗批准后调用)。
  Future<void> approveForSession(
    int runId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final key = _sessionKey(toolName, args);
    if (key == null) return;
    (_sessionApprovals[runId] ??= {})[key] = true;
  }

  /// 清空指定 run 的会话级缓存(run 结束/取消时调用)。
  void resetSession(int runId) {
    _sessionApprovals.remove(runId);
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

  /// readOnly 工具在特定参数下仍需弹窗的例外。
  ///
  /// web_fetch 的 POST 或自定义 headers 可向任意地址提交数据
  /// （包括内网接口），不能按只读无条件放行。
  static bool _readOnlyOverride(String toolName, Map<String, dynamic> args) {
    if (toolName != 'web_fetch') return false;
    final method = args['method'] as String?;
    if (method != null && method.toUpperCase() != 'GET') return true;
    final headers = args['headers'];
    if (headers is Map && headers.isNotEmpty) return true;
    return false;
  }

  /// 会话级缓存 key:
  /// - shell:按「工具 + 动作 + 子命令」缓存——批准 `git push` 后
  ///   `git push --force origin main` 放行（同子命令），但
  ///   `git reset --hard`、`git clean -fdx` 仍需弹窗；
  ///   bash 与 powershell 不共享缓存（key 含工具名）
  /// - 其他:按 toolName + keyArg 精确缓存
  String? _sessionKey(String toolName, Map<String, dynamic> args) {
    final keyArg = _primaryArg(toolName, args);
    if (_isShellTool(toolName)) {
      if (keyArg == null) return null;
      final action = CommandAnalyzer.extractAction(keyArg);
      if (action == null) return 'shell:$toolName:$keyArg';
      final rest =
          keyArg.substring(keyArg.indexOf(action) + action.length).trim();
      final words = rest.isEmpty ? <String>[] : rest.split(RegExp(r'\s+'));
      final sub = words.isEmpty ? null : words.first;
      return 'shell:$toolName:$action${sub != null ? ':$sub' : ''}';
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
