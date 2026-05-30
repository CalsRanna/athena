import 'dart:io';

import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/sandbox.dart';

class PermissionService {
  final PermissionStore _store;
  final PathSandbox _sandbox;

  PermissionService({required PermissionStore store, PathSandbox? sandbox})
      : _store = store,
        _sandbox = sandbox ?? PathSandbox();

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
    if (_matchesDenyRules(toolName, keyArg)) return true;
    // 命令工具：管道到脚本解释器视为危险（隐藏 checkbox，但仍可单次审批）。
    if ((toolName == 'bash' || toolName == 'powershell') &&
        keyArg != null &&
        _sandbox.pipesToInterpreter(keyArg)) {
      return true;
    }
    return false;
  }

  /// 根据工具调用与用户选择的粒度生成 allow 规则。
  ///
  /// [recursive] 仅对文件类工具有效：true=该目录及所有子目录，false=该目录直接子项。
  PermissionRule generateRule(
    String toolName,
    Map<String, dynamic> args, {
    bool recursive = false,
  }) {
    final keyArg = _extractKeyArg(toolName, args);
    switch (toolName) {
      case 'bash' || 'powershell':
        // Shell 永久规则按完整命令字面量匹配，不再按命令前缀放开整个命令族。
        return PermissionRule(tool: toolName, pattern: keyArg ?? '');
      case 'file_read':
      case 'file_write':
      case 'file_update':
      case 'file_delete':
        final dir = _extractDirectory(keyArg ?? '');
        return PermissionRule(
          tool: toolName,
          pattern: dir,
          recursive: recursive,
        );
      case 'search':
      case 'list_directory':
        // keyArg 本身就是用户操作的目录，规则即作用于该目录自身。
        final raw = keyArg ?? '';
        final dir = raw.endsWith('/') ? raw : '$raw/';
        return PermissionRule(
          tool: toolName,
          pattern: dir,
          recursive: recursive,
        );
      default:
        return PermissionRule(tool: toolName);
    }
  }

  /// 生成 checkbox 显示文案
  String generateRuleDescription(
    String toolName,
    Map<String, dynamic> args, {
    bool recursive = false,
  }) {
    final rule = generateRule(toolName, args, recursive: recursive);
    if (rule.pattern == null || rule.pattern!.isEmpty) {
      return 'Always allow $toolName';
    }
    switch (toolName) {
      case 'bash' || 'powershell':
        return 'Always allow this exact command';
      case 'file_read':
        final suffix = recursive ? ' (including subdirectories)' : '';
        return 'Always allow reads in "${rule.pattern}"$suffix';
      case 'file_write':
      case 'file_update':
        final suffix = recursive ? ' (including subdirectories)' : '';
        return 'Always allow writes to "${rule.pattern}"$suffix';
      case 'file_delete':
        final suffix = recursive ? ' (including subdirectories)' : '';
        return 'Always allow deletes in "${rule.pattern}"$suffix';
      case 'search':
        final suffix = recursive ? ' (including subdirectories)' : '';
        return 'Always allow searching in "${rule.pattern}"$suffix';
      case 'list_directory':
        final suffix = recursive ? ' (including subdirectories)' : '';
        return 'Always allow listing in "${rule.pattern}"$suffix';
      default:
        return 'Always allow $toolName matching "${rule.pattern}"';
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
    switch (toolName) {
      case 'bash' || 'powershell':
        return args['command'] as String?;
      case 'file_read':
      case 'file_write':
      case 'file_update':
      case 'file_delete':
        // path 必填：存在则规范化，否则返回 null。
        final path = args['path'] as String?;
        if (path == null) return null;
        return _sandbox.resolveAbsolute(path);
      case 'search':
      case 'list_directory':
        // path 可选，缺省为当前工作目录；规范化后再匹配。
        final path = args['path'] as String? ?? Directory.current.path;
        return _sandbox.resolveAbsolute(path);
      case 'web_fetch':
        return args['url'] as String?;
      default:
        return null;
    }
  }

  String _extractDirectory(String path) {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return path.substring(0, lastSlash + 1);
  }
}
