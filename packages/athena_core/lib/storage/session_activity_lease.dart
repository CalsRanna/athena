import 'dart:io';

import 'package:athena_core/repository/session_rewind_repository.dart';

/// 整个 run 与 rewind 共用的非阻塞锁；数据写锁只保护单次读改写，挡不住
/// 另一前端在回退后继续追加旧 run 的结果。POSIX 锁按进程记账，因此另加
/// 进程内占用表。锁文件永不删除，沿用 file_lock.dart 的 inode 约定。
class FileSessionActivityLease implements SessionActivityLease {
  FileSessionActivityLease._(this._file, this._handle);

  final File _file;
  final RandomAccessFile _handle;
  bool _released = false;
  static final Set<String> _owned = {};

  static Future<FileSessionActivityLease> acquire(File file) async {
    if (!_owned.add(file.path)) {
      throw StateError('Session is busy in another operation.');
    }
    RandomAccessFile? handle;
    try {
      await file.parent.create(recursive: true);
      handle = await file.open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive);
      } on FileSystemException {
        throw StateError(
          'Session is running in another frontend. Stop it there before rewinding.',
        );
      }
      return FileSessionActivityLease._(file, handle);
    } catch (_) {
      try {
        await handle?.close();
      } finally {
        _owned.remove(file.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await _handle.close();
    } finally {
      _owned.remove(_file.path);
    }
  }
}
