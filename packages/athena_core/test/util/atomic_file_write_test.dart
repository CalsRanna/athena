import 'dart:io';

import 'package:athena_core/util/atomic_file_write.dart';
import 'package:test/test.dart';

void main() {
  late String root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_atomic_write_').path;
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  group('内容', () {
    test('新建文件写出内容', () async {
      final file = File('$root/new.txt');

      await replaceFileContent(file, 'hello');

      expect(file.readAsStringSync(), 'hello');
    });

    test('覆盖已有文件', () async {
      final file = File('$root/old.txt')..writeAsStringSync('before');

      await replaceFileContent(file, 'after');

      expect(file.readAsStringSync(), 'after');
    });

    test('父目录不存在时递归创建', () async {
      final file = File('$root/a/b/c.txt');

      await replaceFileContent(file, 'nested');

      expect(file.readAsStringSync(), 'nested');
    });
  });

  group('不跟随最后一段符号链接', () {
    // 这是它与 writeAsString 的实质区别：审批后目标被换成链接时，
    // 顺着链接写会改坏链接指向的文件（例如 ~/.zshrc）。
    test('链接被替换成普通文件，链接原目标一字未动', () async {
      final real = File('$root/real.txt')..writeAsStringSync('original');
      final alias = Link('$root/alias.txt')..createSync(real.path);

      await replaceFileContent(File(alias.path), 'new');

      expect(real.readAsStringSync(), 'original', reason: '绝不能改到链接指向的文件');
      expect(File(alias.path).readAsStringSync(), 'new');
      expect(
        FileSystemEntity.isLinkSync(alias.path),
        isFalse,
        reason: 'rename 不跟随最后一段，链接被普通文件取代',
      );
    });

    // 把上面那条的性质钉死：换成 writeAsString 就会改坏目标文件。
    // 谁要是把 replaceFileContent 简化回 writeAsString，上面那条会红，
    // 这条则说明为什么不能那样简化。
    test('对照：writeAsString 会顺着链接改到目标文件', () async {
      final real = File('$root/real2.txt')..writeAsStringSync('original');
      final alias = Link('$root/alias2.txt')..createSync(real.path);

      File(alias.path).writeAsStringSync('new');

      expect(real.readAsStringSync(), 'new', reason: '这正是要避免的行为');
    });
  });

  group('文件权限', () {
    test('覆盖时保住原有的权限位', () async {
      final file = File('$root/script.sh')..writeAsStringSync('#!/bin/sh\n');
      await Process.run('chmod', ['755', file.path]);
      expect(file.statSync().mode & 0xFFF, 0x1ED, reason: '前置条件：0755');

      await replaceFileContent(file, '#!/bin/sh\necho hi\n');

      // 临时文件是新 inode，默认 0644；不显式套回原 mode 的话，rename 过去
      // 会把可执行脚本变成不可执行——静默的功能损失。
      expect(file.statSync().mode & 0xFFF, 0x1ED);
      expect(file.readAsStringSync(), contains('echo hi'));
    });
  });

  group('失败路径', () {
    test('rename 失败时抛错，且不留下临时文件', () async {
      // 目标位置上是个目录，rename 必然失败。
      Directory('$root/blocked').createSync();

      await expectLater(
        replaceFileContent(File('$root/blocked'), 'x'),
        throwsA(isA<FileSystemException>()),
      );

      final leftovers = Directory(
        root,
      ).listSync().where((e) => e.path.endsWith('.tmp')).toList();
      expect(leftovers, isEmpty, reason: '失败不能留下垃圾');
    });
  });
}
