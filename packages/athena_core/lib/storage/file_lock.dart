import 'dart:io';
import 'dart:math';

import 'package:athena_core/storage/serial_lock.dart';

/// 在 [lockFile] 的排它锁内执行 [action]:先按锁文件路径在**进程内**串行
/// (同一进程里指向同一文件的多个仓储实例互斥),再取**跨进程**文件锁。
///
/// GUI 与 TUI 共享同一数据目录且可能同时运行,单靠进程内的 serialLock
/// 挡不住另一进程的读-改-写交错。每个存储文件配一个独立的 `.lock`
/// 文件(不复用同一把锁:Windows 的文件锁按句柄互斥,嵌套加同一把锁
/// 会自锁死;POSIX 的 fcntl 锁按进程记账,进程内靠上面的串行保证)。
///
/// 锁文件只做互斥,内容始终为空,不参与数据读写。
Future<T> withFileLock<T>(File lockFile, Future<T> Function() action) {
  final key = lockFile.path;
  return serialLock(_inProcess[key], () async {
    await lockFile.parent.create(recursive: true);
    final raf = await lockFile.open(mode: FileMode.append);
    try {
      await raf.lock(FileLock.blockingExclusive);
      return await action();
    } finally {
      try {
        await raf.unlock();
      } catch (_) {
        // close 会释放锁;unlock 失败不影响正确性
      }
      await raf.close();
    }
  }, (f) => _inProcess[key] = f);
}

/// 进程内按锁文件路径的串行队列。
final Map<String, Future<void>> _inProcess = {};

/// [target] 对应的锁文件:同目录下的 `{name}.lock`。
File lockFileFor(File target) => File('${target.path}.lock');

final _random = Random();

/// 原子替换 [target] 的内容:写到同目录的唯一临时文件再 rename。
///
/// 临时文件名带随机后缀:同一进程里多个实例(或另一进程)同时写同一
/// 目标时,固定的 `.tmp` 名会互相覆盖/抢先 rename 导致 PathNotFound。
Future<void> atomicWriteString(File target, String content) async {
  await target.parent.create(recursive: true);
  final suffix = '${pid}_${_random.nextInt(1 << 32)}';
  final tmp = File('${target.path}.$suffix.tmp');
  try {
    // 写入也在 try 内：磁盘满等写入失败时同样要清掉临时文件
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  } catch (_) {
    try {
      await tmp.delete();
    } catch (_) {}
    rethrow;
  }
}

/// 把无法解析的 [file] 复制一份到同目录的 `{name}.corrupt-{时间戳}`，返回
/// 副本路径；文件不存在时返回 null。
///
/// 损坏的数据文件读时按空处理，但下一次写入会以空内容为基础整文件重写，
/// 原内容（手工编辑出一个语法错误的 setting.yaml、写一半的 JSON）就此
/// 永久丢失。写入前先留副本，用户还能把数据找回来。须在该文件的写锁内
/// 调用，避免与另一进程的修复写入交错。
Future<String?> preserveCorruptFile(File file) async {
  if (!await file.exists()) return null;
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final backup = '${file.path}.corrupt-$stamp';
  await file.copy(backup);
  return backup;
}
