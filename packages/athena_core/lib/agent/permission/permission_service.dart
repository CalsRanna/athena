import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/util/logger_util.dart';

/// 权限检查结论。
enum PermissionVerdict {
  /// 放行(会话级命中 / 规则命中)
  allow,

  /// 需要按当前模式审批（手动 / AI 审核 / 直接放行）
  prompt,

  /// 被 deny 规则直接拒绝(不弹窗,调用被 block)
  deny,
}

/// 权限编排:
/// 1. deny 规则扫描:完整调用命中 → 直接拒绝,
///    优先于会话缓存与 allow 规则
/// 2. 会话级缓存:当前 run 内已批准的动作直接放行
/// 3. 持久 allow 规则:命中则放行;未命中 → 交由调用方按审批模式处理
///
/// shell 只匹配整条命令的显式规则,不分析动作、子命令或只读性。
///
/// 会话级缓存按 [runId] 隔离:多个 Agent 并发运行时,
/// A 任务批准的命令不会被 B 任务自动放行。
class PermissionService {
  final PermissionStore _store;
  final Map<int, Map<String, bool>> _sessionApprovals = {};

  PermissionService({required PermissionStore store}) : _store = store;

  /// 检查工具调用是否需要进入审批流程。
  ///
  /// - [allow] → 放行,无需弹窗
  /// - [prompt] → 交由调用方按当前审批模式处理
  /// - [deny] → 被 deny 规则拒绝,调用方应直接 block
  ///
  /// [runId] 为本次 Agent run 的标识(会话级缓存按 run 隔离);
  PermissionVerdict check(
    int runId,
    String toolName,
    Map<String, dynamic> args,
  ) {
    // ① deny 优先:完整调用命中 deny 规则 → 直接拒绝
    final keyArg = _primaryArg(toolName, args) ?? '';
    if (_ruleHits(toolName, keyArg, effect: RuleEffect.deny)) {
      return PermissionVerdict.deny;
    }
    final sessionKey = _sessionKey(toolName, args);
    if (_sessionApprovals[runId]?[sessionKey] == false) {
      return PermissionVerdict.deny;
    }

    // ② 会话级缓存:当前 run 内已批准的动作直接放行
    if (_sessionApprovals[runId]?[sessionKey] == true) {
      return PermissionVerdict.allow;
    }

    // ③ 持久 allow 规则命中则放行
    if (_ruleHits(toolName, keyArg, effect: RuleEffect.allow)) {
      return PermissionVerdict.allow;
    }
    return PermissionVerdict.prompt;
  }

  /// 记录一次会话级放行(弹窗批准后调用)。
  Future<void> approveForSession(
    int runId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final key = _sessionKey(toolName, args);
    (_sessionApprovals[runId] ??= {})[key] = true;
  }

  /// A user denial supersedes earlier consent for this exact call in this run.
  void denyForSession(int runId, String toolName, Map<String, dynamic> args) {
    (_sessionApprovals[runId] ??= {})[_sessionKey(toolName, args)] = false;
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

  /// 是否存在命中的持久规则(按 effect 过滤)。
  ///
  /// 单条损坏规则(畸形 glob 等)只跳过、记日志,不能炸掉
  /// 所有工具调用(历史上一条坏规则曾让所有 bash 报错)。
  bool _ruleHits(String toolName, String keyArg, {required RuleEffect effect}) {
    for (final rule in _store.rules) {
      if (rule.effect != effect) continue;
      try {
        if (rule.matches(toolName, keyArg)) return true;
      } catch (e) {
        LoggerUtil.w('Permission rule skipped (${rule.toJson()}): $e');
      }
    }
    return false;
  }

  /// Reuse approval only for the same tool and complete execution arguments.
  /// A different command flag, workdir, file content or HTTP body needs review.
  /// Display/recommendation metadata and JSON map ordering do not change consent.
  String _sessionKey(String toolName, Map<String, dynamic> args) {
    return jsonEncode([toolName, _sortedJson(toolExecutionArguments(args))]);
  }

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
    // 工具集合统一来自 kFileToolNames / kShellToolNames,避免多处硬编码不一致
    if (kFileToolNames.contains(toolName)) return args['path'] as String?;
    if (kShellToolNames.contains(toolName)) return args['command'] as String?;
    switch (toolName) {
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
