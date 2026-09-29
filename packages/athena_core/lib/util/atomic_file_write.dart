import 'dart:io';
import 'dart:math';

final _random = Random();

/// 原子地把 [target] 的全部内容替换为 [content]：先写同目录临时文件，再 rename。
///
/// 与 `File.writeAsString` 的差别都是安全/完整性问题：
///
/// 1. **不跟随最后一段符号链接。** 审批与执行之间目标可能被换成指向别处的链接，
///    `writeAsString` 会顺着链接写到那个「别处」（把 `~/.zshrc` 覆盖掉）；
///    rename 不跟随最后一段，被换掉的是链接本身，写不到它指向的文件上。
/// 2. **不留半个文件。** 直接写不是原子的，写到一半进程被杀会留下截断的内容。
///
/// 临时文件名带 pid 与随机数：同一目录下并发写同一目标（GUI 与 TUI 同时运行、
/// 或一次并行工具调用）时不会互相覆盖临时文件。`file_lock.dart` 出于同一理由
/// 也是这么取的。
///
/// **必须把原文件的权限位套回临时文件。** 临时文件是新 inode、默认 0644，rename
/// 过去会把 0755 的脚本变成不可执行——实测如此，是一次静默的功能损失。所以目标
/// 已存在时先 chmod 再 rename；chmod 失败就抛错，不做事后补救。
Future<void> replaceFileContent(File target, String content) async {
  await target.parent.create(recursive: true);
  final existingMode = _existingMode(target);
  final temporary = File('${target.path}.$pid.${_random.nextInt(1 << 32)}.tmp');
  try {
    await temporary.writeAsString(content, flush: true);
    if (existingMode != null) await _applyMode(temporary.path, existingMode);
    await temporary.rename(target.path);
  } catch (_) {
    try {
      await temporary.delete();
    } catch (_) {
      // 临时文件可能压根没建成；清理失败也不能盖住原始错误
    }
    rethrow;
  }
}

/// 目标已存在时的权限位（只取低 12 位，不含文件类型）；否则 null。
///
/// Windows 没有 POSIX 权限位，直接返回 null 用默认权限——那里的符号链接创建
/// 还需要额外权限，本节防的那类替换风险本来就低得多。
int? _existingMode(File target) {
  if (Platform.isWindows) return null;
  try {
    final stat = target.statSync();
    if (stat.type == FileSystemEntityType.notFound) return null;
    return stat.mode & 0xFFF;
  } catch (_) {
    // 取不到就当新文件：给默认权限总好过让整次写入失败
    return null;
  }
}

/// 把权限位套到 [path] 上。
///
/// dart:io 没有 chmod，只能起一个进程。用八进制字符串而不是数字：`chmod` 把
/// 纯数字参数当十进制解释，传 493 会得到另一个模式。
Future<void> _applyMode(String path, int mode) async {
  final result = await Process.run('chmod', [mode.toRadixString(8), path]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'chmod ${mode.toRadixString(8)} failed: ${result.stderr}',
      path,
    );
  }
}
