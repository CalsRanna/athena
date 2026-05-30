import 'dart:convert';
import 'dart:io';

class PermissionRule {
  final String tool;
  final String? pattern;
  final String? contains;

  /// 路径类工具（file_read/file_write/file_update/file_delete/search/
  /// list_directory）使用：true 表示该目录及其所有子目录都允许；
  /// false 仅允许该目录及其直接子项。其它工具忽略此字段。
  final bool recursive;

  const PermissionRule({
    required this.tool,
    this.pattern,
    this.contains,
    this.recursive = false,
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      tool: json['tool'] as String,
      pattern: json['pattern'] as String?,
      contains: json['contains'] as String?,
      recursive: json['recursive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool': tool,
      if (pattern != null) 'pattern': pattern,
      if (contains != null) 'contains': contains,
      if (recursive) 'recursive': true,
    };
  }

  bool matchesAllow(String toolName, String? keyArg) {
    if (tool != toolName) return false;
    if (pattern == null) return true;
    if (keyArg == null) return false;

    if (_isFileTool(toolName)) {
      return _matchesPath(pattern!, keyArg, recursive);
    }
    return _globMatch(pattern!, keyArg);
  }

  bool matchesDeny(String toolName, String? keyArg) {
    if (tool != toolName) return false;
    if (contains == null) return true;
    if (keyArg == null) return false;
    return _normalize(keyArg).contains(_normalize(contains!));
  }

  /// 归一化：小写 + 将连续空白折叠为单个空格，抵御大小写/空格规避。
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isFileTool(String toolName) {
    return const {
      'file_read',
      'file_write',
      'file_update',
      'file_delete',
      'search',
      'list_directory',
    }.contains(toolName);
  }

  /// 路径匹配：pattern 是目录前缀，value 是规范化后的绝对路径（文件或目录）。
  /// 规则 `D/` 覆盖目录自身 `D` 及其（递归或直接）子项。
  static bool _matchesPath(String pattern, String value, bool recursive) {
    var dir = pattern;
    if (!dir.endsWith('/')) dir = '$dir/';

    // 规范目录路径无末尾 `/`，规则 `D/` 也应覆盖目录自身 `D`。
    final self = dir.substring(0, dir.length - 1);
    if (value == self) return true;

    if (!value.startsWith(dir)) return false;

    if (recursive) return true;

    // 非递归：value 必须是 dir 的直接子项（dir 之后没有再出现 `/`）
    final tail = value.substring(dir.length);
    return !tail.contains('/');
  }

  static bool _globMatch(String pattern, String value) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return value.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return value == pattern;
  }
}

class PermissionStore {
  List<PermissionRule> allowRules = [];
  List<PermissionRule> denyRules = [];

  static final List<PermissionRule> _builtinDenyRules = [
    PermissionRule(tool: 'bash', contains: 'rm -rf'),
    PermissionRule(tool: 'bash', contains: 'sudo '),
    PermissionRule(tool: 'bash', contains: 'mkfs'),
    PermissionRule(tool: 'bash', contains: '> /dev/'),
    PermissionRule(tool: 'bash', contains: 'dd if='),
    PermissionRule(tool: 'bash', contains: 'chmod 777'),
    PermissionRule(tool: 'bash', contains: ':(){:|:&};:'),
    PermissionRule(tool: 'powershell', contains: 'rm -rf'),
    PermissionRule(tool: 'powershell', contains: 'sudo '),
    PermissionRule(tool: 'powershell', contains: 'mkfs'),
    PermissionRule(tool: 'powershell', contains: '> /dev/'),
    PermissionRule(tool: 'powershell', contains: 'dd if='),
    PermissionRule(tool: 'powershell', contains: 'chmod 777'),
    PermissionRule(tool: 'powershell', contains: ':(){:|:&};:'),
  ];

  File get _file {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return File('$home/.athena/permissions.json');
  }

  Future<void> load() async {
    final file = _file;
    if (!await file.exists()) return;
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      allowRules = (json['allow'] as List?)
              ?.map((e) => PermissionRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      denyRules = (json['deny'] as List?)
              ?.map((e) => PermissionRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (_) {
      allowRules = [];
      denyRules = [];
    }
  }

  Future<void> save() async {
    final file = _file;
    await file.parent.create(recursive: true);
    final json = {
      'allow': allowRules.map((r) => r.toJson()).toList(),
      'deny': denyRules.map((r) => r.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Future<void> addAllowRule(PermissionRule rule) async {
    final exists = allowRules.any(
      (r) =>
          r.tool == rule.tool &&
          r.pattern == rule.pattern &&
          r.recursive == rule.recursive,
    );
    if (exists) return;
    allowRules.add(rule);
    await save();
  }

  List<PermissionRule> get allDenyRules => [..._builtinDenyRules, ...denyRules];
}
