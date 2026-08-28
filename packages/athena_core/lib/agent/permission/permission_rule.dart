import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/util/path_normalizer.dart';

/// 文件路径类工具:规则按路径匹配(路径前缀 + 通配符)。
const kFileToolNames = {'file_read', 'file_write', 'file_update'};

/// Shell 类工具:规则按「动作 + 参数」匹配,命令文本走 [CommandAnalyzer]。
///
/// 与 [kFileToolNames] 对称——新增 shell 工具(zsh/cmd...)只需改这里,
/// 避免 `toolName == 'bash' || toolName == 'powershell'` 散落多处后漏改。
const kShellToolNames = {'bash', 'powershell'};

/// 规则匹配方式(显式存储,不再由 pattern 内容推导)。
///
/// - [action]:shell 工具。匹配命令首个动作(词),pattern 匹配动作后的参数
/// - [exact]:shell 工具。命令 trim 后与 pattern 完全相等(复合命令/管道)
/// - [origin]:web_fetch。pattern 为 URL origin,前缀 + 主机边界
/// - [path]:文件工具。归一化路径 + 目录前缀(/ 边界)或路径 glob
enum RuleKind { action, exact, origin, path }

/// 规则效果。deny 优先于 allow(以及只读/会话缓存等一切放行路径)。
enum RuleEffect { allow, deny }

/// 单条权限规则:工具名 + 匹配方式 + 模式。
///
/// 匹配语义宁窄勿宽:
/// - pattern 为空(任意 kind)→ 允许该工具(及 action,若指定)的所有调用
/// - 通配符(仅 action/path 的 glob 模式):命令参数 `*` 匹配任意文本
///   (含 `/`,`rm -rf *` 必须能拦住 `rm -rf /tmp/x`)、`?` 单个字符;
///   路径 `*` 不跨 `/`,`**` 跨 `/`,`?` 单字符不跨;其余字符按字面匹配
class PermissionRule {
  final String tool;
  final RuleKind kind;

  /// action 规则的命令动作(git、ls...),其余 kind 为 null。
  final String? action;

  /// 匹配模式:action 规则的参数模式 / exact 的完整命令 / origin /
  /// path 目录前缀或路径 glob。空串 = 放行全部。
  final String pattern;

  /// action 规则专属:true → pattern 对参数整串 glob;
  /// false → 参数前缀 + 词边界(允许子命令及其带参变体)。
  final bool wildcard;

  /// 效果:默认放行;deny 规则在权限检查中优先。
  final RuleEffect effect;

  const PermissionRule({
    required this.tool,
    required this.kind,
    this.action,
    this.pattern = '',
    this.wildcard = false,
    this.effect = RuleEffect.allow,
  });

  /// 严格解析;非法组合(kind 与工具不匹配、action 规则缺 action 等)
  /// 返回 null,由存储层跳过——损坏规则不能拖垮整个权限检查。
  static PermissionRule? fromJson(Map<String, dynamic> json) {
    final tool = json['tool'] as String?;
    final kindName = json['kind'] as String?;
    if (tool == null || kindName == null) return null;
    final kind = RuleKind.values.asNameMap()[kindName];
    if (kind == null) return null;
    final action = json['action'] as String?;
    final pattern = json['pattern'] as String? ?? '';
    final wildcard = json['wildcard'] as bool? ?? false;
    final effect = RuleEffect.values.asNameMap()[json['effect'] as String? ?? 'allow'];
    if (effect == null) return null;

    // kind 与工具组合校验:
    // - action 规则仅限 shell 工具且必须带 action
    // - origin 规则仅限 web_fetch
    // - path 规则仅限文件工具
    // - wildcard 仅对 action 规则有意义
    if (kind == RuleKind.action) {
      if ((action == null || action.isEmpty) ||
          !kShellToolNames.contains(tool)) {
        return null;
      }
    } else if (kind == RuleKind.origin && tool != 'web_fetch') {
      return null;
    } else if (kind == RuleKind.path && !kFileToolNames.contains(tool)) {
      return null;
    } else if (wildcard) {
      return null;
    }
    return PermissionRule(
      tool: tool,
      kind: kind,
      action: action,
      pattern: pattern,
      wildcard: wildcard,
      effect: effect,
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool,
        'kind': kind.name,
        if (effect == RuleEffect.deny) 'effect': 'deny',
        if (action != null) 'action': action,
        'pattern': pattern,
        if (wildcard) 'wildcard': true,
      };

  /// 从完整命令生成规则(「始终允许」落库用):
  ///
  /// - 简单命令(`git status`、`ls -la /x`)→ action 规则,参数含
  ///   `*`/`?` 时按 glob(wildcard: true),否则按前缀+词边界
  ///   (`git push origin main` 放行 `git push origin main -f` 等带参变体)
  /// - 复合命令(`git status && npm test`)→ 按子命令分别建模(最多 5 条,
  ///   同 Claude Code)。`cd` 子命令无副作用不存规则;子命令过多或括号
  ///   不平衡时退化为整条 exact(保守)
  /// - 未识别首词 → exact 整串
  static List<PermissionRule> fromCommand(String tool, String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return [PermissionRule(tool: tool, kind: RuleKind.exact)];
    }
    final subs = CommandAnalyzer.splitSubcommands(trimmed);
    if (subs.length > 1) {
      final rules = <PermissionRule>[];
      for (final sub in subs) {
        // cd 本身无副作用,工作目录变更归后续子命令的规则管
        if (CommandAnalyzer.extractAction(sub) == 'cd') continue;
        rules.add(_ruleForSingleCommand(tool, sub));
      }
      if (rules.isEmpty || rules.length > 5) {
        // 全部是 cd(或空白)/无法可靠拆分:整条精确匹配
        return [PermissionRule(tool: tool, kind: RuleKind.exact, pattern: trimmed)];
      }
      return rules;
    }
    return [_ruleForSingleCommand(tool, trimmed)];
  }

  /// 「始终允许」落库用:按工具类别选择规则形态。
  ///
  /// - shell 工具 → [fromCommand](复合命令按子命令拆成多条)
  /// - 文件工具   → [RuleKind.path](归一化路径前缀 / glob)
  /// - web_fetch  → [RuleKind.origin](scheme://host[:port])
  /// - 其余工具,或 [keyArg] 缺失 → 空 pattern 的 [RuleKind.exact],
  ///   即放行该工具的所有调用
  static List<PermissionRule> forToolCall(String tool, String? keyArg) {
    if (keyArg == null) {
      return [PermissionRule(tool: tool, kind: RuleKind.exact)];
    }
    if (kShellToolNames.contains(tool)) return fromCommand(tool, keyArg);
    if (kFileToolNames.contains(tool)) {
      return [PermissionRule(tool: tool, kind: RuleKind.path, pattern: keyArg)];
    }
    if (tool == 'web_fetch') {
      return [
        PermissionRule(tool: tool, kind: RuleKind.origin, pattern: keyArg),
      ];
    }
    return [PermissionRule(tool: tool, kind: RuleKind.exact)];
  }

  static PermissionRule _ruleForSingleCommand(String tool, String command) {
    final trimmed = command.trim();
    final actionWord = CommandAnalyzer.extractAction(trimmed);
    if (actionWord != null &&
        !actionWord.startsWith('/') &&
        !actionWord.contains('://')) {
      final rest =
          trimmed.substring(trimmed.indexOf(actionWord) + actionWord.length)
              .trim();
      return PermissionRule(
        tool: tool,
        kind: RuleKind.action,
        action: actionWord,
        pattern: rest,
        wildcard: rest.contains('*') || rest.contains('?'),
      );
    }
    return PermissionRule(
      tool: tool,
      kind: RuleKind.exact,
      pattern: trimmed,
    );
  }

  /// [keyArg] 是归一化后的参数(路径/命令/origin)。
  /// [action] 是调用方解析出的 shell 命令动作(git、ls...),仅 action 规则需要。
  bool matches(String toolName, String? keyArg, {String? action}) {
    if (tool != toolName) return false;

    switch (kind) {
      case RuleKind.action:
        // action 规则先校验动作一致性,再按 pattern 匹配;
        // pattern 为空 → 允许该动作的所有调用
        if (this.action != action) return false;
        if (pattern.isEmpty) return true;
        if (keyArg == null) return false;
        return _matchesArgs(_stripAction(keyArg));
      case RuleKind.exact:
        // pattern 为空 → 允许该工具的所有调用
        if (pattern.isEmpty) return true;
        if (keyArg == null) return false;
        return keyArg.trim() == pattern.trim();
      case RuleKind.origin:
        if (pattern.isEmpty) return true;
        if (keyArg == null) return false;
        return _matchesOrigin(keyArg);
      case RuleKind.path:
        if (pattern.isEmpty) return true;
        if (keyArg == null) return false;
        return _matchesPath(keyArg);
    }
  }

  /// 从完整命令中剥离动作前缀。
  /// `'git status -s'` → `'status -s'`;参数为空 → null。
  String? _stripAction(String? keyArg) {
    if (keyArg == null) return null;
    final trimmed = keyArg.trim();
    if (!trimmed.startsWith(action!)) return keyArg;
    final rest = trimmed.substring(action!.length).trim();
    return rest.isEmpty ? null : rest;
  }

  /// action 规则的参数匹配:glob 整串,或前缀 + 词边界。
  bool _matchesArgs(String? args) {
    if (args == null) return false;
    if (wildcard) return _globMatch(pattern, args);
    if (args == pattern) return true;
    if (!args.startsWith(pattern)) return false;
    return _isWhitespace(args[pattern.length]);
  }

  /// origin 匹配:前缀 + 主机边界(`:` 端口或 `/` 路径)。
  ///
  /// `https://a.com` 命中 `https://a.com/api` 与 `https://a.com:8080/x`,
  /// 不命中 `https://a.com.evil.com`。
  bool _matchesOrigin(String keyArg) {
    if (keyArg == pattern) return true;
    if (!keyArg.startsWith(pattern)) return false;
    final next = keyArg[pattern.length];
    return next == ':' || next == '/';
  }

  /// 路径匹配:归一化(分隔符、.. 词法解析、相对路径绝对化)后,
  /// 含通配符按路径 glob,否则目录前缀(/ 边界)。
  bool _matchesPath(String keyArg) {
    var p = normalizePathForMatch(pattern);
    var k = normalizePathForMatch(keyArg);
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (k.endsWith('/')) k = k.substring(0, k.length - 1);
    if (p.contains('*') || p.contains('?')) {
      return _globMatch(p, k, slashSensitive: true);
    }
    return k == p || k.startsWith('$p/');
  }

  /// 通配符 → 正则,按域区分:
  ///
  /// - 命令参数([slashSensitive] false):`*` 匹配任意文本(含 `/`),
  ///   `?` 单个字符——`Bash(rm -rf *)` 必须拦住 `rm -rf /tmp/x`
  /// - 路径([slashSensitive] true):`*` 不跨 `/`,`**` 跨 `/`,
  ///   `?` 单字符不跨 `/`(`rm *.log` 在路径语义下不变宽)
  ///
  /// 先 RegExp.escape 转义全部元字符,再还原通配符——`(` `|` `[` 等
  /// 一律按字面匹配,从根上避免把含 grep 正则的命令拼进 RegExp 后
  /// 编译失败(FormatException: Unterminated group)或正则注入。
  static bool _globMatch(
    String glob,
    String value, {
    bool slashSensitive = false,
  }) {
    var escaped = RegExp.escape(glob);
    if (slashSensitive) {
      escaped = escaped
          .replaceAll(r'\*\*', '___DSTAR___')
          .replaceAll(r'\*', r'[^/]*')
          .replaceAll(r'\?', r'[^/]')
          .replaceAll('___DSTAR___', r'.*');
    } else {
      escaped = escaped.replaceAll(r'\*', r'.*').replaceAll(r'\?', '.');
    }
    return RegExp('^$escaped\$').hasMatch(value);
  }

  static bool _isWhitespace(String char) =>
      char == ' ' || char == '\t' || char == '\n';
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
          .whereType<Map<String, dynamic>>()
          .map(PermissionRule.fromJson)
          .whereType<PermissionRule>()
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
          r.kind == rule.kind &&
          r.action == rule.action &&
          r.pattern == rule.pattern &&
          r.wildcard == rule.wildcard,
    );
    if (exists) return;
    rules.add(rule);
    await save();
  }
}
