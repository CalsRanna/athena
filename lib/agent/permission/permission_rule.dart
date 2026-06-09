import 'dart:convert';
import 'dart:io';

/// 单条权限规则：工具名 + 前缀模式。
///
/// - 文件类工具：pattern 为目录前缀，匹配该目录及所有子目录
/// - Shell 工具：pattern 为命令前缀，如 "git " 匹配所有 git 命令
/// - web_fetch：pattern 为 URL origin（scheme://host[:port]）
/// - pattern 为空表示允许该工具的所有调用
class PermissionRule {
  final String tool;
  final String pattern;

  const PermissionRule({required this.tool, this.pattern = ''});

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      tool: json['tool'] as String,
      pattern: json['pattern'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool,
        'pattern': pattern,
      };

  /// [keyArg] 是归一化后的参数（路径/命令/origin）。
  ///
  /// 路径类工具：keyArg 等于 pattern（去掉尾斜杠）或以 `pattern/` 为前缀。
  /// 非路径工具：keyArg 以 pattern 为前缀（shell 命令、URL origin 等）。
  bool matches(String toolName, String? keyArg) {
    if (tool != toolName) return false;
    if (pattern.isEmpty) return true;
    if (keyArg == null) return false;

    if (_isFilePathTool(tool)) {
      var p = pattern;
      if (p.endsWith('/')) p = p.substring(0, p.length - 1);
      var k = keyArg;
      if (k.endsWith('/')) k = k.substring(0, k.length - 1);
      return k == p || k.startsWith('$p/');
    }

    return keyArg.startsWith(pattern);
  }

  static bool _isFilePathTool(String toolName) {
    return const {
      'file_read', 'file_write', 'file_update', 'file_delete',
      'search', 'list_directory',
    }.contains(toolName);
  }
}

/// 规则持久化存储（`~/.athena/permissions.json`）。
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
      (r) => r.tool == rule.tool && r.pattern == rule.pattern,
    );
    if (exists) return;
    rules.add(rule);
    await save();
  }
}
