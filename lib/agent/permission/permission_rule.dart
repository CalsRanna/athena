import 'dart:convert';
import 'dart:io';

class PermissionRule {
  final String tool;
  final String? prefix;
  final String? contains;

  const PermissionRule({required this.tool, this.prefix, this.contains});

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      tool: json['tool'] as String,
      prefix: json['prefix'] as String?,
      contains: json['contains'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool': tool,
      if (prefix != null) 'prefix': prefix,
      if (contains != null) 'contains': contains,
    };
  }

  bool matchesAllow(String toolName, String? keyArg) {
    if (tool != toolName) return false;
    if (prefix == null) return true;
    if (keyArg == null) return false;
    return keyArg.startsWith(prefix!);
  }

  bool matchesDeny(String toolName, String? keyArg) {
    if (tool != toolName) return false;
    if (contains == null) return true;
    if (keyArg == null) return false;
    return keyArg.contains(contains!);
  }
}

class PermissionStore {
  List<PermissionRule> allowRules = [];
  List<PermissionRule> denyRules = [];

  static final List<PermissionRule> _builtinDenyRules = [
    PermissionRule(tool: 'shell', contains: 'rm -rf'),
    PermissionRule(tool: 'shell', contains: 'sudo '),
    PermissionRule(tool: 'shell', contains: 'mkfs'),
    PermissionRule(tool: 'shell', contains: '> /dev/'),
    PermissionRule(tool: 'shell', contains: 'dd if='),
    PermissionRule(tool: 'shell', contains: 'chmod 777'),
    PermissionRule(tool: 'shell', contains: ':(){:|:&};:'),
  ];

  File get _file {
    final home = Platform.environment['HOME'] ?? '';
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
      (r) => r.tool == rule.tool && r.prefix == rule.prefix,
    );
    if (exists) return;
    allowRules.add(rule);
    await save();
  }

  List<PermissionRule> get allDenyRules => [..._builtinDenyRules, ...denyRules];
}
