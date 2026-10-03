import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/path_normalizer.dart';

/// 文件路径类工具:规则按路径匹配(路径前缀 + 通配符)。
const kFileToolNames = {'file_read', 'file_write', 'file_update'};

/// Shell 类工具:禁令按整条命令匹配，不分析命令语义。
///
/// 与 [kFileToolNames] 对称——新增 shell 工具(zsh/cmd...)只需改这里,
/// 避免 `toolName == 'bash' || toolName == 'powershell'` 散落多处后漏改。
const kShellToolNames = {'bash', 'powershell'};

/// 规则匹配方式(显式存储,不再由 pattern 内容推导)。
///
/// - [exact]:shell 工具。折叠空白并去掉参数末尾的 `/` 后匹配完整命令
/// - [origin]:web_fetch。pattern 为 URL origin,前缀 + 主机边界
/// - [path]:文件工具。归一化路径 + 目录前缀(/ 边界)或路径 glob
enum RuleKind { exact, origin, path }

/// 单条持久禁令:工具名 + 匹配方式 + 模式。
///
/// 匹配语义宁窄勿宽:
/// - pattern 为空(任意 kind)→ 匹配该工具的所有调用
/// - 仅路径支持通配符:`*` 不跨 `/`,`**` 跨 `/`,`?` 单字符不跨;
///   命令内容按字面匹配,不解析命令语法
class PermissionRule {
  final String tool;
  final RuleKind kind;

  /// 匹配模式:exact 的完整命令 / origin /
  /// path 目录前缀或路径 glob。空串 = 禁止该工具全部调用。
  final String pattern;

  const PermissionRule({
    required this.tool,
    required this.kind,
    this.pattern = '',
  });

  /// 严格解析;旧 allow、非法组合或已移除的 action 规则
  /// 返回 null,由存储层跳过——损坏规则不能拖垮整个权限检查。
  static PermissionRule? fromJson(Map<String, dynamic> json) {
    final tool = json['tool'] as String?;
    final kindName = json['kind'] as String?;
    if (tool == null || kindName == null) return null;
    final kind = RuleKind.values.asNameMap()[kindName];
    if (kind == null) return null;
    final pattern = json['pattern'] as String? ?? '';
    final wildcard = json['wildcard'] as bool? ?? false;
    // 旧 allow 规则（包括省略 effect 的旧格式）停止生效，绝不能改读成 deny。
    if (json['effect'] != 'deny') return null;

    // origin/path 只适用于对应工具;旧的命令通配符配置不再支持。
    if (kind == RuleKind.origin && tool != 'web_fetch') {
      return null;
    } else if (kind == RuleKind.path && !kFileToolNames.contains(tool)) {
      return null;
    } else if (wildcard) {
      return null;
    }
    return PermissionRule(tool: tool, kind: kind, pattern: pattern);
  }

  Map<String, dynamic> toJson() => {
    'tool': tool,
    'kind': kind.name,
    'effect': 'deny',
    'pattern': pattern,
  };

  /// [keyArg] 是归一化后的参数(路径/命令/origin)。
  bool matches(String toolName, String? keyArg) {
    if (tool != toolName) return false;

    switch (kind) {
      case RuleKind.exact:
        // pattern 为空 → 禁止该工具的所有调用
        if (pattern.isEmpty) return true;
        if (keyArg == null) return false;
        if (kShellToolNames.contains(toolName)) {
          return _normalizeCommandForDenyMatch(keyArg) ==
              _normalizeCommandForDenyMatch(pattern);
        }
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

  /// deny 规则用的 shell 命令归一化：折叠空白、去掉每个参数末尾的 `/`。
  ///
  /// 这不是命令语义分析：`rm -fr ~`、`/bin/rm -rf ~`、`bash -c 'rm -rf ~'`
  /// 仍不匹配 `rm -rf ~`。不要把文本规则当成完整的沙箱边界。
  /// 按空白切词会打散引号结构；这里只守住最常见的空白与末尾斜杠扰动。
  static String _normalizeCommandForDenyMatch(String command) {
    return command
        .trim()
        .split(RegExp(r'\s+'))
        .map((token) {
          var trimmed = token;
          // 保留单独的 `/`：`rm -rf /` 不能被归一化成 `rm -rf`
          while (trimmed.length > 1 && trimmed.endsWith('/')) {
            trimmed = trimmed.substring(0, trimmed.length - 1);
          }
          return trimmed;
        })
        .join(' ');
  }

  /// 路径匹配:归一化(分隔符、.. 词法解析、相对路径绝对化)后,
  /// 含通配符按路径 glob,否则目录前缀(/ 边界)。
  ///
  /// 两侧都解析符号链接(通配符段不存在,原样保留):执行侧的 keyArg 已由
  /// `applyRunWorkspace` 解析为真实路径,若 pattern 仍是词法路径,写在链接
  /// 目录下的规则(macOS 的 `/tmp` 即 `/private/tmp`)不再命中,deny 规则
  /// 也能被链接绕开。对已解析的 keyArg 再解析一次结果不变。
  bool _matchesPath(String keyArg) {
    var p = resolveRealPathSync(pattern);
    var k = resolveRealPathSync(keyArg);
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (k.endsWith('/')) k = k.substring(0, k.length - 1);
    if (p.contains('*') || p.contains('?')) {
      return _globMatch(p, k);
    }
    return k == p || k.startsWith('$p/');
  }

  /// 路径通配符 → 正则:`*` 不跨 `/`,`**` 跨 `/`,`?` 单字符不跨 `/`。
  ///
  /// 先 RegExp.escape 转义全部元字符,再还原通配符——`(` `|` `[` 等
  /// 一律按字面匹配,避免路径中的正则元字符造成编译失败或正则注入。
  static bool _globMatch(String glob, String value) {
    final escaped = RegExp.escape(glob)
        .replaceAll(r'\*\*', '___DSTAR___')
        .replaceAll(r'\*', r'[^/]*')
        .replaceAll(r'\?', r'[^/]')
        .replaceAll('___DSTAR___', r'.*');
    return RegExp('^$escaped\$').hasMatch(value);
  }
}

/// 规则持久化存储(`FileStorage.permissionsFile`,GUI 与 TUI 共用)。
///
/// GUI 与 TUI 共用这个文件,用户也会手工编辑它(deny 规则只能手写):
/// - **写**:跨进程锁内「读磁盘最新内容 → 合并 → 原子写回」,不拿进程里的
///   旧列表整表覆盖——否则另一端刚加的规则、手写的 deny 会被静默抹掉
/// - **读**:[load] 之后每次 [refreshIfChanged] 按 mtime / 大小发现外部修改
///   并重读,另一端新加的 deny 不用等重启才生效
/// - **损坏**:单条坏规则跳过并记日志;整文件解析失败时保留内存中最后一份
///   有效规则,下次写入前把坏文件备份成 `.corrupt-{时间戳}` 再重写
///
/// 未调用 [load] 的实例只用内存里的 [rules](测试用),不读磁盘。落盘文件与它的
/// 锁都由装配层从数据根传入,**不再自己拼 `$HOME`**:否则换了数据根(移动端、
/// TUI 的 `--data-dir`)之后,规则仍会写进真实主目录。
class PermissionStore {
  /// [file] 与 [locks] 成对提供:[file] 是落点,[locks] 决定它的锁放哪(见
  /// [LockRegistry])。都不提供 = 纯内存实例(测试)。
  PermissionStore({File? file, LockRegistry? locks})
    : _file = file,
      _locks = file == null
          ? null
          : locks ??
                (throw ArgumentError(
                  'Locking the permissions file requires a LockRegistry '
                  'configured with that file',
                ));

  /// 落盘文件;null = 纯内存实例,此时 [_locks] 也为 null。
  final File? _file;

  /// 锁放哪由它决定;仅当 [_file] 非空时非空。
  final LockRegistry? _locks;

  List<PermissionRule> rules = [];

  bool _loaded = false;
  (DateTime, int)? _loadedStamp;

  /// 开始与磁盘同步。没配置落盘文件时调用它是装配错误:那意味着本该持久化的
  /// 规则会静默只留在内存里,重启即丢。
  Future<void> load() async {
    if (_file == null) {
      throw StateError('PermissionStore has no backing file; cannot load()');
    }
    _loaded = true;
    _reload();
  }

  /// 文件自上次读取后被改过(另一进程写入、手工编辑)就重读。
  ///
  /// 同步实现:权限检查是同步的,且在每次工具调用前执行;未变化时只有
  /// 一次 stat。
  void refreshIfChanged() {
    if (!_loaded) return;
    if (_stamp() != _loadedStamp) _reload();
  }

  Future<void> add(PermissionRule rule) async {
    if (!_loaded) {
      // 纯内存实例(测试):不落盘
      if (!_contains(rules, rule)) rules.add(rule);
      return;
    }
    final file = _file!;
    final locks = _locks!;
    await withFileLock(locks.forTarget(file), () async {
      var current = _parse(file);
      if (current == null) {
        // 坏文件以内存里最后一份有效规则为基础重写,先留备份
        final backup = await preserveCorruptFile(file);
        LoggerUtil.w('${file.path} is corrupt, backed up to $backup');
        current = List.of(rules);
      }
      if (!_contains(current, rule)) current.add(rule);
      await atomicWriteString(
        file,
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'rules': current.map((r) => r.toJson()).toList()}),
      );
      rules = current;
      _loadedStamp = _stamp();
    });
  }

  void _reload() {
    final parsed = _parse(_file!);
    // 解析失败保留已有规则:清空会让 deny 规则在这段时间里失效
    if (parsed != null) rules = parsed;
    _loadedStamp = _stamp();
  }

  (DateTime, int)? _stamp() {
    final stat = _file!.statSync();
    if (stat.type == FileSystemEntityType.notFound) return null;
    return (stat.modified, stat.size);
  }

  /// 读取并解析规则文件。文件不存在返回空列表;整体无法解析返回 null。
  static List<PermissionRule>? _parse(File file) {
    final String content;
    try {
      if (!file.existsSync()) return [];
      content = file.readAsStringSync();
    } catch (e) {
      LoggerUtil.w('Failed to read ${file.path}: $e');
      return null;
    }
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final list = json['rules'] as List? ?? const [];
      final result = <PermissionRule>[];
      for (final item in list) {
        final rule = item is Map<String, dynamic>
            ? PermissionRule.fromJson(item)
            : null;
        if (rule != null) {
          result.add(rule);
        } else {
          // 旧 allow 与 action 规则按设计停止生效，同样落在这里
          LoggerUtil.w('Permission rule skipped: $item');
        }
      }
      return result;
    } catch (e) {
      LoggerUtil.w('${file.path} is not valid JSON: $e');
      return null;
    }
  }

  static bool _contains(List<PermissionRule> list, PermissionRule rule) =>
      list.any(
        (r) =>
            r.tool == rule.tool &&
            r.kind == rule.kind &&
            r.pattern == rule.pattern,
      );
}
