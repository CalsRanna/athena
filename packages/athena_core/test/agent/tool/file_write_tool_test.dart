import 'dart:io';

import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:test/test.dart';

void main() {
  late String root;
  final tool = FileWriteTool();

  setUp(() {
    // 临时目录在 macOS 上位于符号链接之下（/var → /private/var），
    // 以真实路径为基准，路径复核才不会把基准本身当成「链接被替换」。
    root = normalizePathForMatch(
      Directory.systemTemp
          .createTempSync('athena_file_write_')
          .resolveSymbolicLinksSync(),
    );
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  Future<String> write(String path, String content) =>
      tool.execute({'path': path, 'content': content});

  test('新建文件写出内容', () async {
    final result = await write('$root/new.txt', 'hello');

    expect(result, startsWith('Successfully wrote'));
    expect(File('$root/new.txt').readAsStringSync(), 'hello');
  });

  test('覆盖已有文件', () async {
    File('$root/old.txt').writeAsStringSync('before');

    await write('$root/old.txt', 'after');

    expect(File('$root/old.txt').readAsStringSync(), 'after');
  });

  test('父目录不存在时递归创建', () async {
    await write('$root/deep/nested/file.txt', 'nested');

    expect(File('$root/deep/nested/file.txt').readAsStringSync(), 'nested');
  });

  test('覆盖可执行脚本后 0755 仍在', () async {
    // 写入走「临时文件 + rename」；临时文件默认 0644，不把原 mode 套回去
    // 就会把脚本改成不可执行——这条是那次改动的回归护栏。
    final file = File('$root/run.sh')..writeAsStringSync('#!/bin/sh\nold\n');
    await Process.run('chmod', ['755', file.path]);
    expect(file.statSync().mode & 0xFFF, 0x1ED, reason: '前置条件：0755');

    await write(file.path, '#!/bin/sh\nnew\n');

    expect(file.statSync().mode & 0xFFF, 0x1ED);
    expect(file.readAsStringSync(), '#!/bin/sh\nnew\n');
  });
}
