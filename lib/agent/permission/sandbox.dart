import 'dart:io';

class PathSandbox {
  final List<String> allowedPaths;
  final List<String> deniedPaths;

  PathSandbox({
    List<String>? allowedPaths,
    List<String>? deniedPaths,
  })  : allowedPaths = allowedPaths ?? [Directory.current.path],
        deniedPaths = deniedPaths ?? [
          '$_home/.ssh',
          '$_home/.aws',
          '/etc',
          '/System',
        ];

  static String get _home {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return home;
  }

  bool canRead(String path) {
    final resolved = _resolve(path);
    if (_isDenied(resolved)) return false;
    return _isAllowed(resolved);
  }

  bool canWrite(String path) {
    final resolved = _resolve(path);
    if (_isDenied(resolved)) return false;
    return _isAllowed(resolved);
  }

  bool canExecute(String command) {
    final dangerous = ['rm -rf /', 'sudo ', 'chmod 777 /', 'mkfs.'];
    return !dangerous.any((d) => command.contains(d));
  }

  bool _isAllowed(String path) {
    return allowedPaths.any((a) => path.startsWith(_resolve(a)));
  }

  bool _isDenied(String path) {
    return deniedPaths.any((d) => path.startsWith(_resolve(d)));
  }

  String _resolve(String path) {
    if (path.startsWith('~/')) {
      return '$_home/${path.substring(2)}';
    }
    if (path.startsWith('/')) return path;
    return '${Directory.current.path}/$path';
  }
}
