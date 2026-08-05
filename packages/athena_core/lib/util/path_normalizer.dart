import 'dart:io';

import 'package:path/path.dart' as p;

/// 归一化文件路径,使权限匹配与工具执行使用同一条路径。
///
/// - 分隔符统一为 '/'（Windows 反斜杠 → 正斜杠）
/// - 词法解析 `..` / `.`（`p.normalize`,不访问文件系统）
/// - 相对路径基于当前进程工作目录绝对化
///
/// 作用：堵住 `allowed_dir/../../.ssh/authorized_keys` 型路径穿越——
/// 规则匹配与 `File(path)` 执行都基于归一化结果,穿越后的路径
/// 不再命中允许目录的前缀规则。
String normalizePathForMatch(String path) {
  var abs = p.normalize(path);
  if (!p.isAbsolute(abs)) {
    abs = p.join(Directory.current.path, abs);
  }
  // Windows 上 p.normalize/join 返回反斜杠分隔，统一为正斜杠
  return abs.replaceAll('\\', '/');
}

/// Best-effort 解析符号链接与真实路径（文件不存在时回退到词法归一化）。
///
/// 与 [normalizePathForMatch] 配合：规则层只做词法归一化（同步、
/// 不访问文件系统），工具执行前再 canonicalize——若真实路径与规则
/// 匹配路径不一致则规则不命中、走弹窗（偏安全）。
Future<String> canonicalizePathForExecution(String path) async {
  final normalized = normalizePathForMatch(path);
  try {
    // resolveSymbolicLinks（旧 API File.canonicalize 在 Dart 3.12 移除）
    final real = await File(normalized).resolveSymbolicLinks();
    return normalizePathForMatch(real);
  } catch (_) {
    // 文件不存在（新建/不存在的读取目标）无法解析,用词法结果
    return normalized;
  }
}

/// 判断归一化后的绝对路径是否触及敏感凭据位置（.ssh / .aws / .athena /
/// .env* / credentials / id_rsa / id_ed25519）。
///
/// 按路径段精确匹配,避免子串误伤（如 `my.credentials.txt` 不算——
/// 段名是 `my.credentials.txt`,不是 `credentials`）。
bool isSensitivePath(String normalizedPath) {
  final segments = normalizedPath.split('/');
  for (final seg in segments) {
    final lower = seg.toLowerCase();
    if (lower == '.ssh' ||
        lower == '.aws' ||
        lower == '.athena' ||
        lower == 'credentials' ||
        lower == 'id_rsa' ||
        lower == 'id_ed25519' ||
        lower == '.env' ||
        lower.startsWith('.env.')) {
      return true;
    }
  }
  return false;
}
