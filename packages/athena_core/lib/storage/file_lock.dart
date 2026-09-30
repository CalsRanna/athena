import 'dart:io';

import 'package:athena_core/storage/serial_lock.dart';
import 'package:athena_core/util/atomic_file_write.dart';
import 'package:path/path.dart' as p;

/// 在 [lockFile] 的排它锁内执行 [action]:先按锁文件路径在**进程内**串行
/// (同一进程里指向同一文件的多个仓储实例互斥),再取**跨进程**文件锁。
///
/// GUI 与 TUI 共享同一数据目录且可能同时运行,单靠进程内的 serialLock
/// 挡不住另一进程的读-改-写交错。每个目标配一个独立的锁文件,不复用同一把
/// 锁:Windows 的文件锁按句柄互斥,嵌套加同一把锁会自锁死;POSIX 的 fcntl
/// 锁按进程记账,进程内靠上面的串行保证。锁文件的位置由 [LockRegistry] 决定。
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

/// 数据目录里锁文件的统一位置:`<root>/.locks/`。
///
/// 锁文件全在这里,数据目录(`providers/`、`sentinels/`、`sessions/`……)只装
/// 数据。锁按数据根内的**相对路径镜像**命名,于是 `.locks/sessions/{id}.jsonl.lock`
/// 一眼能看出它保护的是谁。
///
/// **锁文件不是缓存,不要删。** 文件锁按 inode 记账:删掉一个正被别处持有的
/// 锁文件,后来者会在新的 inode 上加锁,双方以为拿到了同一把锁,互斥静默失效。
/// 所以实体被删掉、迁移跑完之后留下的空锁文件是刻意的;要清理只能在**所有前端
/// 都退出**之后整体删掉 `.locks/`。
///
/// 目标必须落在 [root] 之内:给不出相对路径时抛 [ArgumentError],而不是退回
/// 「哈希成一个全局名字」——那会变成两套并存的命名规则,调用方再也无法从锁反查
/// 它保护的是谁。
class LockRegistry {
  LockRegistry(this.root);

  final Directory root;

  Directory get directory => Directory(p.join(root.path, '.locks'));

  /// [target] 对应的锁文件。
  File forTarget(File target) => _mirror(target.path);

  /// [directory] 自身的锁:整目录替换时用,与对其中单条记录的写互斥。
  File forDirectory(Directory directory) => _mirror(directory.path);

  /// 不对应单个数据实体的锁:一次性迁移。允许带 `/`,中间目录会被创建。
  File named(String name) => File(p.join(directory.path, '$name.lock'));

  File _mirror(String path) {
    final absolute = p.absolute(path);
    final from = p.absolute(root.path);
    if (!p.isWithin(from, absolute)) {
      throw ArgumentError.value(
        path,
        'path',
        'Lock targets must live under ${root.path}',
      );
    }
    final relative = p.relative(absolute, from: from);
    return File('${p.join(directory.path, relative)}.lock');
  }
}

/// 原子替换 [target] 的内容:写到同目录的唯一临时文件再 rename。
///
/// 实现已统一到 [replaceFileContent]——连符号链接窗口与权限位一起处理，
/// 这里只保留这个更贴存储语境的旧名字供既有调用点使用。
Future<void> atomicWriteString(File target, String content) =>
    replaceFileContent(target, content);

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
