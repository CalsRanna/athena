import 'dart:io';

import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/sandbox.dart';

/// 权限编排：
/// - L0: 沙箱黑名单硬拦截
/// - L1: 用户持久化规则自动放行
/// - L2: 无匹配 → 弹出审批弹窗（由调用方处理）
class PermissionService {
  final PermissionStore _store;
  final PathSandbox _sandbox;

  PermissionService({required PermissionStore store, PathSandbox? sandbox})
      : _store = store,
        _sandbox = sandbox ?? PathSandbox();

  /// 检查工具调用是否需要弹窗。
  /// - `true`  → 规则命中，自动允许，无需弹窗
  /// - `false` → 沙箱拦截，直接拒绝，无需弹窗
  /// - `null`  → 需要弹出审批弹窗
  bool? check(String toolName, Map<String, dynamic> args) {
    final keyArg = _primaryArg(toolName, args);

    // L0: 文件类工具先过沙箱
    if (_isFilePathTool(toolName) && keyArg != null) {
      if (!_sandbox.canAccess(keyArg)) return false;
    }

    // L1: 持久化规则
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
      'bash' || 'powershell' => 'Always allow this command',
      'file_read' => 'Always allow reads in this directory',
      'file_write' || 'file_update' => 'Always allow writes in this directory',
      'file_delete' => 'Always allow deletes in this directory',
      'search' => 'Always allow searching in this directory',
      'list_directory' => 'Always allow listing this directory',
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
      case 'file_delete':
        final p = args['path'] as String?;
        return p != null ? _sandbox.resolveAbsolute(p) : null;
      case 'search':
      case 'list_directory':
        final p = (args['path'] as String?) ?? Directory.current.path;
        return _sandbox.resolveAbsolute(p);
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

  static bool _isFilePathTool(String toolName) {
    return const {
      'file_read',
      'file_write',
      'file_update',
      'file_delete',
      'search',
      'list_directory',
    }.contains(toolName);
  }
}
