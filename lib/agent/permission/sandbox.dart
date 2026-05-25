import 'dart:io';

import 'package:path/path.dart' as p;

/// L0 硬黑名单：通用 Agent 的最低安全边界。
///
/// 沙箱模型：除黑名单外，整台电脑都是潜在工作区，具体准入由 PermissionService
/// 通过用户审批决定。黑名单内的路径无论何种审批都直接拒绝。
class PathSandbox {
  /// 黑名单绝对路径（已 canonicalize、末尾无 `/`）。
  final List<String> deniedPaths;

  PathSandbox({List<String>? deniedPaths})
      : deniedPaths = (deniedPaths ?? _defaultDeniedPaths())
            .map(_canonicalize)
            .toList();

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
  static bool _hasPipeToShell(String command) {
    final pattern = RegExp(r'\|\s*(sh|bash|zsh|ksh|csh|tcsh|fish)\b');
    return pattern.hasMatch(command);
  }

  /// 检测 `rm -rf <根级路径或 home 关键子项>`。
  static bool _hasDestructiveRm(String command) {
    final segments = _splitByOperators(command);
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (!RegExp(r'^rm\b').hasMatch(trimmed)) continue;
      // 必须有 -r 或 -rf 或 -fr 或 -R
      if (!RegExp(r'(^|\s)-[rR][fF]?(\s|$)|(^|\s)-[fF][rR](\s|$)|(^|\s)--recursive\b')
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
    final pattern = RegExp(r'>\s*([^\s|;&]+)');
    for (final match in pattern.allMatches(command)) {
      final target = match.group(1);
      if (target == null) continue;
      try {
        if (_isDeniedStatic(target)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// 静态版本的 _isDenied，用于命令检测阶段。
  static bool _isDeniedStatic(String path) {
    final resolved = _canonicalize(path);
    for (final denied in _defaultDeniedPaths().map(_canonicalize)) {
      if (resolved == denied) return true;
      if (resolved.startsWith('$denied/')) return true;
    }
    return false;
  }

  /// 路径是否"接近根"或指向 home 关键子项。
  static bool _isRootLikeTarget(String token) {
    final stripped = token.replaceAll(RegExp(r'^["\047]|["\047]$'), '');
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
    return command.split(RegExp(r'(?:\|\||\&\&|[;|])'));
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
