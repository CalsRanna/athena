import 'dart:io';

import 'package:path/path.dart' as p;

/// L0 硬黑名单：通用 Agent 的最低安全边界。
///
/// 沙箱模型：除黑名单外，整台电脑都是潜在工作区，具体准入由 PermissionService
/// 通过用户审批决定。黑名单内的路径无论何种审批都直接拒绝。
class PathSandbox {
  /// 黑名单绝对路径（已 canonicalize、末尾无 `/`）。
  final List<String> deniedPaths;

  PathSandbox({List<String>? deniedPaths, String? dataDirectory})
      : deniedPaths = [
          ...(deniedPaths ?? _defaultDeniedPaths()),
          // 应用数据目录（含明文 API key 的 athena.db）纳入黑名单，
          // 阻止 Agent 经 file_read/search/file_write 读写密钥库（S7）。
          if (dataDirectory != null) dataDirectory,
        ].map(_canonicalize).toList();

  /// L0 检查：路径是否可读。
  bool canRead(String path) => !_isDenied(path);

  /// L0 检查：路径是否可写。
  bool canWrite(String path) => !_isDenied(path);

  /// L0 检查：命令是否可执行。token-aware 黑名单。
  bool canExecute(String command) {
    final lower = command.toLowerCase();

    if (_containsToken(lower, 'sudo') || _containsToken(lower, 'doas')) {
      return false;
    }

    // fork bomb 关键 token
    if (lower.contains(':(){') || lower.contains(':|:&')) return false;

    if (lower.contains('mkfs') || lower.contains('dd if=')) return false;

    if (_hasPipeToShell(command)) return false;

    if (_hasDestructiveRm(command)) return false;

    if (_hasRedirectToDenied(command)) return false;

    return true;
  }

  /// 公开版本的路径解析，供工具构造审批文案使用。
  String resolveAbsolute(String path) => _canonicalize(path);

  /// 检测命令是否管道到脚本解释器（python/node/perl/ruby）。
  ///
  /// 注意：这 *不* 参与 [canExecute] 的硬拒绝判定——管道到解释器有合法用途
  /// （如 `cat data.json | python -m json.tool`）。它仅供 PermissionService
  /// 的"危险"判定使用，从而隐藏"始终允许"勾选框（命令仍可单次审批后执行）。
  bool pipesToInterpreter(String command) {
    return RegExp(r'\|\s*(python[23]?|node|perl|ruby)\b', caseSensitive: false)
        .hasMatch(command);
  }

  bool _isDenied(String path) {
    final resolved = _canonicalize(path);
    for (final denied in deniedPaths) {
      if (resolved == denied) return true;
      if (resolved.startsWith('$denied/')) return true;
    }
    return false;
  }

  /// 解析 `~`、相对路径、`..`、symlink，统一为绝对规范路径。
  static String _canonicalize(String path) {
    var expanded = path;
    if (expanded.startsWith('~/')) {
      expanded = p.join(_home, expanded.substring(2));
    } else if (expanded == '~') {
      expanded = _home;
    }

    if (!p.isAbsolute(expanded)) {
      expanded = p.absolute(expanded);
    }

    var normalized = p.canonicalize(expanded);

    // 解析 symlink。若文件不存在则按字面路径处理（这是常见情况，
    // 例如 file_write 的目标路径尚未创建）；只对已存在的路径解析真实位置。
    try {
      if (FileSystemEntity.isLinkSync(normalized) ||
          FileSystemEntity.typeSync(normalized) !=
              FileSystemEntityType.notFound) {
        normalized = File(normalized).resolveSymbolicLinksSync();
      }
    } catch (_) {
      // 解析失败保持 canonicalize 结果，不暴露内部错误
    }

    // 去末尾 `/`
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String get _home {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }

  /// 检查 token 在 command 中独立出现（不是 substring）。
  static bool _containsToken(String command, String token) {
    final pattern = RegExp(r'(^|[\s;|&(`])' +
        RegExp.escape(token) +
        r'($|[\s;|&)`])');
    return pattern.hasMatch(command);
  }

  /// 检测 `... | sh` / `... | bash` / `... | zsh` 类管道到 shell。
  ///
  /// 仅覆盖真正的 shell（硬拒绝）。管道到脚本解释器（python/node/perl/ruby）
  /// 不在此处——它有合法用途，改由 [pipesToInterpreter] 标记为"危险"。
  static bool _hasPipeToShell(String command) {
    final pattern = RegExp(r'\|\s*(sh|bash|zsh|ksh|csh|tcsh|fish)\b',
        caseSensitive: false);
    return pattern.hasMatch(command);
  }

  /// 检测 `rm -rf <根级路径或 home 关键子项>`。
  static bool _hasDestructiveRm(String command) {
    final segments = _splitByOperators(command);
    for (final segment in segments) {
      // 剥离前导环境变量赋值（如 `FOO=1 rm -rf /`），使命令名能正确锚定。
      final trimmed = _stripLeadingAssignments(segment.trim());
      // 匹配 `rm` 或以 `/bin/rm`、`/usr/bin/rm` 等绝对/相对路径调用的 rm。
      if (!RegExp(r'^(\S*/)?rm\b', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }
      // 必须有 -r 或 -rf 或 -fr 或 -R
      if (!RegExp(
              r'(^|\s)-[rR][fF]?(\s|$)|(^|\s)-[fF][rR](\s|$)|(^|\s)--recursive\b',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }
      // 提取参数（排除 -flag）
      final tokens = trimmed
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty && !t.startsWith('-'))
          .skip(1) // skip "rm"
          .toList();
      for (final t in tokens) {
        if (_isRootLikeTarget(t)) return true;
      }
    }
    return false;
  }

  /// 检测重定向写入黑名单目录或根目录。
  static bool _hasRedirectToDenied(String command) {
    // 匹配重定向：可选 fd 前缀（数字或 `&`）+ `>` 或 `>>`，随后是目标路径。
    // 例如 `> f`、`>> f`、`1> f`、`2>> f`、`&> f`。目标可能带引号。
    final redirect = RegExp(r'''(?:\d+|&)?>>?\s*("[^"]+"|'[^']+'|[^\s|;&<>]+)''');
    for (final match in redirect.allMatches(command)) {
      final target = match.group(1);
      if (target == null || target.isEmpty) continue;
      try {
        if (_isDeniedStatic(_stripQuotes(target))) return true;
      } catch (_) {}
    }

    // 检测 `tee`（含 `tee -a`）：tee 会写入其文件参数（无需 `>`）。
    if (_hasTeeToDenied(command)) return true;

    return false;
  }

  /// 检测 `tee` / `tee -a` 写入黑名单路径。
  static bool _hasTeeToDenied(String command) {
    final segments = _splitByOperators(command);
    for (final segment in segments) {
      final tokens = segment
          .trim()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isEmpty) continue;
      // 命令名为首个非环境变量赋值的 token（如 `FOO=1 tee ...`）。
      final cmdIndex = tokens.indexWhere((t) => !RegExp(r'^\w+=').hasMatch(t));
      if (cmdIndex < 0) continue;
      // tee 可能以绝对/相对路径调用（如 /usr/bin/tee）。
      final cmd = tokens[cmdIndex].split('/').last;
      if (cmd.toLowerCase() != 'tee') continue;
      // tee 之后的非 flag 参数即为目标文件。
      for (final t in tokens.skip(cmdIndex + 1)) {
        if (t.startsWith('-')) continue;
        try {
          if (_isDeniedStatic(_stripQuotes(t))) return true;
        } catch (_) {}
      }
    }
    return false;
  }

  /// 剥离 token 首尾的成对引号。
  static String _stripQuotes(String s) {
    return s.replaceAll(RegExp(r'''^["']|["']$'''), '');
  }

  /// 剥离命令段开头的环境变量赋值 token（如 `FOO=1 BAR=x rm ...`）。
  static String _stripLeadingAssignments(String segment) {
    var rest = segment;
    final assignment = RegExp(r'^\w+=\S*\s+');
    while (true) {
      final m = assignment.firstMatch(rest);
      if (m == null) break;
      rest = rest.substring(m.end);
    }
    return rest;
  }

  /// 静态版本的 _isDenied，用于命令检测阶段。
  static bool _isDeniedStatic(String path) {
    final denied = _defaultDeniedPaths().map(_canonicalize).toList();
    for (final candidate in {_canonicalize(path), _canonicalizeViaAncestor(path)}) {
      for (final d in denied) {
        if (candidate == d) return true;
        if (candidate.startsWith('$d/')) return true;
      }
    }
    return false;
  }

  /// 当目标路径尚不存在时，`_canonicalize` 无法解析其父目录上的 symlink
  /// （如 `/etc` -> `/private/etc`）。此处解析最近的已存在祖先目录的真实位置，
  /// 再拼回剩余路径，以堵住经 symlink 目录写入黑名单的命令注入。
  static String _canonicalizeViaAncestor(String path) {
    var base = _canonicalize(path);
    final segments = <String>[];
    while (true) {
      if (FileSystemEntity.typeSync(base) != FileSystemEntityType.notFound) {
        try {
          final real = File(base).resolveSymbolicLinksSync();
          if (segments.isEmpty) return real;
          return p.joinAll([real, ...segments.reversed]);
        } catch (_) {
          break;
        }
      }
      final parent = p.dirname(base);
      if (parent == base) break; // 到达根
      segments.add(p.basename(base));
      base = parent;
    }
    return _canonicalize(path);
  }

  /// 路径是否"接近根"或指向 home 关键子项。
  static bool _isRootLikeTarget(String token) {
    final stripped = _stripQuotes(token);
    final resolved = _canonicalize(stripped);

    // 根目录或一级子目录（如 `/`、`/usr`、`/Users`）
    if (resolved == '/') return true;
    final slashCount = '/'.allMatches(resolved).length;
    if (resolved.startsWith('/') && slashCount <= 2) {
      // 明确临时目录除外
      const safeRoots = ['/tmp', '/var/folders', '/private/tmp', '/private/var/folders'];
      if (safeRoots.any((s) => resolved == s || resolved.startsWith('$s/'))) {
        return false;
      }
      return true;
    }

    // 用户 home 本身
    if (resolved == _home) return true;

    return false;
  }

  static List<String> _splitByOperators(String command) {
    return command.split(RegExp(r'(?:\|\||\&\&|[;|\n\r])'));
  }

  static List<String> _defaultDeniedPaths() {
    final home = _home;
    final paths = <String>[
      // 通用：Athena 自身配置
      '$home/.athena',
      // 凭据 / 密钥
      '$home/.ssh',
      '$home/.aws',
      '$home/.gnupg',
      '$home/.config/op',
      '$home/.config/gh/hosts.yml',
      '$home/.docker/config.json',
      '$home/.netrc',
      '$home/.pgpass',
    ];

    if (Platform.isMacOS) {
      paths.addAll([
        '$home/Library/Application Support/Google/Chrome',
        '$home/Library/Application Support/Firefox',
        '$home/Library/Application Support/Microsoft Edge',
        '$home/Library/Cookies',
        '$home/Library/Keychains',
        '$home/Library/Application Support/1Password',
        '/etc',
        '/System',
        '/private/var/db',
        '/private/etc',
      ]);
    } else if (Platform.isLinux) {
      paths.addAll([
        '$home/.mozilla',
        '$home/.config/google-chrome',
        '$home/.config/chromium',
        '$home/.config/BraveSoftware',
        '/etc',
        '/proc',
        '/sys',
        '/boot',
      ]);
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (appData != null) {
        paths.addAll([
          '$appData\\Microsoft\\Credentials',
          '$appData\\Microsoft\\Crypto',
        ]);
      }
      if (localAppData != null) {
        paths.addAll([
          '$localAppData\\Google\\Chrome\\User Data',
          '$localAppData\\Microsoft\\Edge\\User Data',
          '$localAppData\\Mozilla\\Firefox',
        ]);
      }
      paths.add('C:\\Windows\\System32\\config');
    }

    return paths;
  }
}
