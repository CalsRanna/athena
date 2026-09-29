import 'dart:io';

import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:test/test.dart';

void main() {
  late String root;
  final tool = FileReadTool();

  setUp(() {
    // 临时目录在 macOS 上位于符号链接之下（/var → /private/var），
    // 以真实路径为基准，路径复核才不会把基准本身当成「链接被替换」。
    root = normalizePathForMatch(
      Directory.systemTemp
          .createTempSync('athena_file_read_')
          .resolveSymbolicLinksSync(),
    );
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  Future<String> read(String path) => tool.execute({'path': path});

  group('凭据路径是硬拦', () {
    // 这条拦截发生在审批之后、且无条件返回。原文案写的是「requires approval」，
    // 读起来像「批准了就能读」——而批准在这里根本不起作用，模型会以为换个说法
    // 或重试就能过。文案必须与行为一致：写侧的 protectedWritePathError 一直是
    // 「is not allowed」，读侧应对齐。
    test('文案说的是不允许，不是需要审批', () async {
      final result = await read('$root/.ssh/id_rsa');

      expect(result, startsWith('Error: Blocked:'));
      expect(result, contains('not allowed'));
      expect(
        result,
        isNot(contains('requires approval')),
        reason: '批准满足不了这条拦截，不能让模型以为再试一次就能过',
      );
    });

    for (final segment in [
      '.ssh',
      '.aws',
      '.athena',
      '.env',
      'credentials',
      'id_rsa',
      'id_ed25519',
    ]) {
      test('$segment 段一律拒绝', () async {
        expect(await read('$root/$segment/x'), startsWith('Error: Blocked:'));
      });
    }

    test('段落按整段匹配，子串不误伤', () async {
      // my.credentials.txt 的段名不是 credentials，不该被当成凭据拦掉。
      final file = File('$root/my.credentials.txt')
        ..writeAsStringSync('not a secret\n');

      expect(await read(file.path), contains('not a secret'));
    });
  });

  group('普通路径', () {
    test('正常读取', () async {
      final file = File('$root/note.txt')..writeAsStringSync('hello\n');

      expect(await read(file.path), contains('hello'));
    });

    test('文件不存在时报错而不是被当成凭据', () async {
      expect(await read('$root/nope.txt'), contains('File not found'));
    });
  });
}
