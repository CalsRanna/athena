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

/// 同步解析符号链接，得到调用真正会读写的路径（Windows 下为 best-effort）。
///
/// 权限判定（规则、会话缓存、AI 审核、审批卡）与执行都必须基于这个结果：
/// 只做词法归一化时，`docs/setup.md -> ~/.zshrc` 这样的链接会让审批看到
/// 项目内路径、实际却写到主目录。逐段解析而不是直接
/// `resolveSymbolicLinksSync`，是因为后者要求整条路径存在——新建文件、
/// 链接到不存在目标的悬空链接（写入会凭空创建目标）都得一并解析。
/// 目标尚不存在的尾部原样保留。
String resolveRealPathSync(String path) {
  final normalized = normalizePathForMatch(path);
  try {
    final parts = p.split(normalized);
    var resolved = parts.first;
    final pending = parts.sublist(1);
    var hops = 0;
    while (pending.isNotEmpty) {
      final segment = pending.removeAt(0);
      if (segment == '.') continue;
      if (segment == '..') {
        resolved = p.dirname(resolved);
        continue;
      }
      final candidate = p.join(resolved, segment);
      if (FileSystemEntity.typeSync(candidate, followLinks: false) !=
          FileSystemEntityType.link) {
        resolved = candidate;
        continue;
      }
      // 与内核的 ELOOP 上限同量级，防止链接环
      if (++hops > 40) return normalized;
      final target = Link(candidate).targetSync();
      final absolute = p.isAbsolute(target) ? target : p.join(resolved, target);
      final targetParts = p.split(absolute);
      resolved = targetParts.first;
      pending.insertAll(0, targetParts.sublist(1));
    }
    return normalizePathForMatch(resolved);
  } catch (_) {
    // 无权读取链接等异常：退回词法结果，执行侧的复核会拦住不一致
    return normalized;
  }
}

/// 执行前复核路径：[path] 应已由 `applyRunWorkspace` 解析为真实路径。
///
/// 返回 null 表示路径仍指向审批时的位置；否则返回解析后的真实路径——
/// 说明审批之后链接被替换（或调用方传入了未解析的路径），调用方应拒绝执行，
/// 让新的真实路径重新走一遍审批。
String? realPathChangedSinceApproval(String path) {
  final real = resolveRealPathSync(path);
  return real == normalizePathForMatch(path) ? null : real;
}

/// [realPathChangedSinceApproval] 命中时回给模型的错误：让它用真实路径
/// 重新发起调用，从而按真实目标重新审批。
String symlinkChangedError(String path, String realPath) =>
    'Error: $path resolves through a symbolic link to $realPath, which was '
    'not the path reviewed for this call. Call the tool again with the real '
    'path if you still intend to access it.';

String protectedWritePathError(String path) =>
    'Error: Blocked: writing to credential or Athena data directories '
    '($path) is not allowed. Athena data is managed by its own tools.';

/// 写入禁区：凭据目录与应用数据目录（`~/.athena` 由仓储管理，写
/// `permissions.json` 等于给自己授权）。只拦写入而不像读取那样连 `.env`
/// 一并拦截——写 `.env` 不会把密钥带进上下文，仍按正常审批处理。
bool isProtectedWritePath(String normalizedPath) {
  for (final seg in normalizedPath.split('/')) {
    final lower = seg.toLowerCase();
    if (lower == '.ssh' || lower == '.aws' || lower == '.athena') return true;
  }
  return false;
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
