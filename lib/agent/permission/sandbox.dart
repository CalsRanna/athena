import 'dart:io';

import 'package:path/path.dart' as p;

/// 路径黑名单沙箱 —— 阻止 Agent 访问敏感凭据/系统目录。
///
/// 仅做 L0 硬拦截，不做命令语义分析。其余权限由审批弹窗交由用户判断。
class PathSandbox {
  final List<String> deniedPaths;

  PathSandbox({List<String>? deniedPaths, String? dataDirectory})
      : deniedPaths = <String>[
          ..._defaultDeniedPaths(),
          ...(deniedPaths ?? []),
          if (dataDirectory != null) dataDirectory,
        ].map(_canonicalize).toList();

  /// 路径是否可通过黑名单检查。
  bool canAccess(String path) => !_isDenied(path);

  // 兼容现有工具代码的别名
  bool canRead(String path) => canAccess(path);
  bool canWrite(String path) => canAccess(path);

  /// 归一化路径（解析 ~ / .. / symlink），供规则匹配使用。
  String resolveAbsolute(String path) => _canonicalize(path);

  bool _isDenied(String path) {
    final resolved = _canonicalize(path);
    for (final denied in deniedPaths) {
      if (resolved == denied || resolved.startsWith('$denied/')) return true;
    }
    return false;
  }

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
    try {
      final type = FileSystemEntity.typeSync(normalized);
      if (type != FileSystemEntityType.notFound) {
        normalized = File(normalized).resolveSymbolicLinksSync();
      }
    } catch (_) {}
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

  static List<String> _defaultDeniedPaths() {
    final home = _home;
    final paths = <String>[
      '$home/.athena',
      '$home/.ssh',
      '$home/.aws',
      '$home/.gnupg',
    ];
    if (Platform.isMacOS) {
      paths.addAll([
        '$home/Library/Keychains',
        '/etc',
        '/System',
        '/private/etc',
      ]);
    } else if (Platform.isLinux) {
      paths.addAll([
        '/etc',
        '/proc',
        '/sys',
        '/boot',
      ]);
    }
    return paths;
  }
}
