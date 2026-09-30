import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 锁文件的位置规则:集中在数据根的 `.locks/` 下,并镜像数据文件的相对路径。
///
/// 这条映射是跨进程互斥的全部依据——两个进程必须为同一个数据文件算出同一个
/// 锁路径,所以它是契约,不是实现细节。
void main() {
  late Directory tmp;
  late LockRegistry locks;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_locks_');
    locks = LockRegistry(tmp);
  });

  tearDown(() => tmp.delete(recursive: true));

  test('数据根内的文件镜像到 .locks/ 下', () {
    final target = File(p.join(tmp.path, 'sessions', '01a0.jsonl'));
    expect(
      locks.forTarget(target).path,
      p.join(tmp.path, '.locks', 'sessions', '01a0.jsonl.lock'),
    );
  });

  test('根目录下的数据文件也不与锁混在同一层', () {
    final lock = locks.forTarget(File(p.join(tmp.path, 'setting.yaml')));
    expect(lock.path, p.join(tmp.path, '.locks', 'setting.yaml.lock'));
    expect(lock.parent.path, isNot(tmp.path));
  });

  test('两个仓库实例(两个进程)对同一文件算出同一把锁', () {
    final target = File(p.join(tmp.path, 'sessions', 'x.jsonl'));
    final other = LockRegistry(Directory(p.absolute(tmp.path)));
    expect(locks.forTarget(target).path, other.forTarget(target).path);
  });

  test('目录锁与一次性迁移锁也在 .locks/ 下', () {
    expect(
      locks.forDirectory(Directory(p.join(tmp.path, 'sentinels'))).path,
      p.join(tmp.path, '.locks', 'sentinels.lock'),
    );
    expect(
      locks.named('migrations/storage').path,
      p.join(tmp.path, '.locks', 'migrations', 'storage.lock'),
    );
  });

  test('数据根之外的路径给不出映射:抛错,不退回另一套命名', () {
    expect(
      () => locks.forTarget(File(p.join(tmp.parent.path, 'elsewhere.jsonl'))),
      throwsArgumentError,
    );
  });

  test('加锁会建出中间目录,锁文件内容为空', () async {
    final lock = locks.forTarget(File(p.join(tmp.path, 'sessions', 'x.jsonl')));
    final content = await withFileLock(lock, () async {
      expect(await lock.parent.exists(), isTrue);
      return lock.readAsBytes();
    });
    expect(content, isEmpty);
  });

  test('同一把锁上的操作按提交顺序串行', () async {
    final lock = locks.forTarget(File(p.join(tmp.path, 'x.yaml')));
    var inFlight = 0;
    var peak = 0;
    final order = <int>[];
    await Future.wait([
      for (var i = 0; i < 5; i++)
        withFileLock(lock, () async {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          order.add(i);
          inFlight--;
        }),
    ]);
    expect(peak, 1, reason: '同进程内同一把锁不能并发进入');
    expect(order, [0, 1, 2, 3, 4], reason: '按提交顺序执行');
  });
}
