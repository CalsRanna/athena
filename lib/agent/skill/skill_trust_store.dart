import 'dart:convert';
import 'dart:io';

/// 持久化「已信任的项目级 Skill 目录」集合。
///
/// 文件 JSON 结构（镜像 PermissionStore 的 map 风格）：
/// ```json
/// {
///   "trustedDirs": ["/abs/path/a", "/abs/path/b"]
/// }
/// ```
///
/// 默认存储位置：`$HOME/.athena/trusted_skill_dirs.json`。
/// `isTrusted` 必须同步（SkillRegistry.loadAll 是同步的）；首次访问时
/// 惰性加载并缓存。读取容忍文件缺失/损坏（视为空集，不抛异常）。
class SkillTrustStore {
  SkillTrustStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;
  Set<String>? _trusted;

  static File _defaultFile() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return File('$home/.athena/trusted_skill_dirs.json');
  }

  /// 规范化路径：去除末尾斜杠，使 `/a/b` 与 `/a/b/` 比较相等。
  /// 输入已是绝对路径；不解析符号链接，保持确定性。
  static String _normalize(String dirPath) {
    var p = dirPath;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  Set<String> _load() {
    final cached = _trusted;
    if (cached != null) return cached;

    final set = <String>{};
    if (_file.existsSync()) {
      try {
        final json = jsonDecode(_file.readAsStringSync());
        if (json is Map<String, dynamic>) {
          final dirs = json['trustedDirs'];
          if (dirs is List) {
            for (final e in dirs) {
              if (e is String) set.add(_normalize(e));
            }
          }
        }
      } catch (_) {
        // 损坏文件视为空集。
      }
    }
    _trusted = set;
    return set;
  }

  bool isTrusted(String dirPath) {
    return _load().contains(_normalize(dirPath));
  }

  Future<void> trust(String dirPath) async {
    final set = _load();
    set.add(_normalize(dirPath));
    await _file.parent.create(recursive: true);
    final json = {'trustedDirs': set.toList()};
    await _file.writeAsString(jsonEncode(json));
  }
}
