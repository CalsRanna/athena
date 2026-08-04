import 'dart:convert';
import 'dart:io';

/// 文件路径类工具:规则按路径匹配(路径前缀 + 通配符)。
const kFileToolNames = {'file_read', 'file_write', 'file_update'};

/// 单条权限规则:工具名 + 动作(可选)+ 通配符模式。
///
/// - 文件类工具:pattern 为路径,支持 * 和 ? 通配符
/// - Shell 工具:action 为命令动作(git、ls、npm...),pattern 为参数模式
/// - web_fetch:pattern 为 URL origin(scheme://host[:port])
/// - pattern 为空表示允许该工具(及 action,若指定)的所有调用
///
/// 兼容旧格式:action 为 null 时,规则退化为旧的完整字符串前缀匹配。
class PermissionRule {
  final String tool;
  final String? action;
  final String pattern;

  const PermissionRule({
    required this.tool,
    this.action,
    this.pattern = '',
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      tool: json['tool'] as String,
      action: json['action'] as String?,
      pattern: json['pattern'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool,
        if (action != null) 'action': action,
        'pattern': pattern,
      };

  /// [keyArg] 是归一化后的参数(路径/命令/origin)。
  /// [action] 是调用方解析出的 shell 命令动作(git、ls...),仅 shell 工具需要。
  ///
  /// 支持 * 和 ? 通配符:
  /// - * 匹配任意字符(包括路径分隔符)
  /// - ? 匹配单个字符
  /// - 不加通配符时行为同前缀匹配(向后兼容)
  bool matches(String toolName, String? keyArg, {String? action}) {
    if (tool != toolName) return false;

    // 动作级规则:调用方动作必须与规则动作一致
    if (this.action != null) {
      if (action == null || action != this.action) return false;
      // action 命中;pattern 为空 → 允许该动作的所有调用
      if (pattern.isEmpty) return true;
      // pattern 匹配剥离动作前缀后的参数部分
      return _matchesArg(_stripAction(keyArg));
    }

    // 旧规则(无 action):完整字符串匹配,行为不变
    if (pattern.isEmpty) return true;
    if (keyArg == null) return false;
    return _matchesArg(keyArg);
  }

  /// 从完整命令中剥离动作前缀,返回参数部分。
  /// `'git status -s'` → `'status -s'`;参数为空 → null。
  String? _stripAction(String? keyArg) {
    if (keyArg == null) return null;
    final trimmed = keyArg.trim();
    if (!trimmed.startsWith(action!)) return keyArg;
    final rest = trimmed.substring(action!.length).trim();
    return rest.isEmpty ? null : rest;
  }

  bool _matchesArg(String? keyArg) {
    if (pattern.isEmpty) return true;
    if (keyArg == null) return false;

    if (kFileToolNames.contains(tool)) {
      var p = pattern;
      if (p.endsWith('/')) p = p.substring(0, p.length - 1);
      var k = keyArg;
      if (k.endsWith('/')) k = k.substring(0, k.length - 1);
      // 路径类:使用通配符匹配 + 向下兼容的目录前缀匹配
      if (p.contains('*') || p.contains('?')) {
        return _globMatch(p, k);
      }
      return k == p || k.startsWith('$p/');
    }

    // 非路径工具:使用通配符匹配 + 向下兼容的前缀匹配
    if (pattern.contains('*') || pattern.contains('?')) {
      return _globMatch(pattern, keyArg);
    }
    return keyArg.startsWith(pattern);
  }

  /// 简单的通配符匹配:* → .*  ,  ? → .
  bool _globMatch(String glob, String value) {
    final escaped = glob
        .replaceAll('.', r'\.')
        .replaceAll('*', r'[___STAR___]')
        .replaceAll('?', r'[___QM___]')
        .replaceAll('[___STAR___]', r'[^/]*')
        .replaceAll('[___QM___]', '.');
    return RegExp('^$escaped\$').hasMatch(value);
  }
}

/// 规则持久化存储(`~/.athena/permissions.json`)。
class PermissionStore {
  List<PermissionRule> rules = [];

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
      final list = json['rules'] as List?;
      if (list == null) return;
      rules = list
          .map((e) => PermissionRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      rules = [];
    }
  }

  Future<void> save() async {
    final file = _file;
    await file.parent.create(recursive: true);
    final json = {
      'rules': rules.map((r) => r.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Future<void> add(PermissionRule rule) async {
    final exists = rules.any(
      (r) =>
          r.tool == rule.tool &&
          r.action == rule.action &&
          r.pattern == rule.pattern,
    );
    if (exists) return;
    rules.add(rule);
    await save();
  }
}
