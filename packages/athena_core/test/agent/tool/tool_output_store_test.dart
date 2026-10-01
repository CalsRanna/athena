import 'dart:io';

import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:test/test.dart';

void main() {
  late String root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_output_store_').path;
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  String longText([int extra = 100]) =>
      'a' * (ToolOutputStore.inlineLimit + extra);

  /// 一个必定写不进去的目录：它的父路径是一个普通文件，create 会以
  /// ENOTDIR 失败。用不可写目录来造这个错误在不同平台上不一致（root 能写）。
  Directory unwritableDirectory() {
    final blocker = File('$root/blocker')..writeAsStringSync('not a directory');
    return Directory('${blocker.path}/sub');
  }

  group('落盘成功时行为不变', () {
    for (final disk in [false, true]) {
      test(
        'Unicode pagination and checkpoints agree with original text (disk=$disk)',
        () async {
          final store = ToolOutputStore(
            directory: disk ? Directory('$root/outputs') : null,
          );
          final text = '\uFEFF${'A😀中文' * 6000}';
          final id = await store.save(text);
          final all = text.runes.toList();
          for (final offset in [0, 4090, 8190, 16000, 24000, 4096]) {
            final page = await store.read(id, offset: offset, limit: 20);
            expect(page.text, String.fromCharCodes(all.skip(offset).take(20)));
            expect(page.nextOffset, offset + page.text.runes.length);
          }
        },
      );
    }

    test(
      'two stores can atomically save the same output concurrently',
      () async {
        final directory = Directory('$root/outputs');
        final first = ToolOutputStore(directory: directory);
        final second = ToolOutputStore(directory: directory);
        final ids = await Future.wait([
          first.save(longText()),
          second.save(longText()),
        ]);
        expect(ids[0], ids[1]);
        expect((await second.read(ids.first, limit: 10)).text, 'a' * 10);
      },
    );
    test('超长输出转存并给出可读回的引用', () async {
      final store = ToolOutputStore(directory: Directory('$root/outputs'));

      final result = await store.prepare(longText());

      expect(result.outputId, isNotNull);
      expect(result.modelResult, contains('[tool_output id='));
      expect(result.modelResult, contains('tool_output_read'));

      final page = await store.read(result.outputId!, limit: 10);
      expect(page.text, 'a' * 10);
      expect(page.hasMore, isTrue);
    });

    test('短输出直接内联，不落盘', () async {
      final store = ToolOutputStore(directory: Directory('$root/outputs'));

      final result = await store.prepare('short');

      expect(result.modelResult, 'short');
      expect(result.outputId, isNull);
    });

    test('内存模式（无目录）照常转存与读回', () async {
      final store = ToolOutputStore();

      final result = await store.prepare(longText());

      expect(result.outputId, isNotNull);
      final page = await store.read(result.outputId!, limit: 10);
      expect(page.text, 'a' * 10);
    });
  });

  group('落盘失败时降级而不是冒泡', () {
    test('prepare 不抛异常，交还内联预览并明说读不回来', () async {
      final store = ToolOutputStore(directory: unwritableDirectory());

      final result = await store.prepare(longText());

      expect(result.modelResult, startsWith('[tool_output not saved]'));
      expect(result.modelResult, contains('tool_output_read cannot retrieve'));
      expect(result.outputId, isNull, reason: '没存下来就不能报出 outputId');
      // 原文前段要保留，否则模型连「跑出了什么」都不知道。
      expect(result.modelResult, endsWith('a' * ToolOutputStore.inlineLimit));
    });

    test('落盘失败不影响短输出（走内联快路径）', () async {
      final store = ToolOutputStore(directory: unwritableDirectory());

      final result = await store.prepare('short');

      expect(result.modelResult, 'short');
      expect(result.outputId, isNull);
    });

    test('reference 不抛异常，压不下去就交还原文', () async {
      final store = ToolOutputStore(directory: unwritableDirectory());
      final content = longText();

      final referenced = await store.reference(content);

      expect(referenced, content, reason: '宁可让预算检查明确报装不下，也不静默截断');
    });

    test('restore 不抛异常', () async {
      final store = ToolOutputStore(directory: unwritableDirectory());

      await expectLater(
        store.restore(longText(), modelResult: 'compressed'),
        completes,
      );
    });
  });
}
