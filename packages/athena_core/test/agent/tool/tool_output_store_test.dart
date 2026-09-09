import 'dart:io';

import 'package:athena_core/agent/tool/tool_output_read_tool.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:test/test.dart';

void main() {
  for (final onDisk in [false, true]) {
    group(onDisk ? 'disk outputs' : 'memory outputs', () {
      late ToolOutputStore store;
      Directory? directory;
      setUp(() async {
        if (onDisk) {
          directory = await Directory.systemTemp.createTemp('tool-outputs-');
        }
        store = ToolOutputStore(directory: directory);
      });
      tearDown(() async => directory?.delete(recursive: true));

      test('22KB and boundary-sized results pass through unchanged', () async {
        for (final length in [0, 22196, ToolOutputStore.inlineLimit]) {
          final raw = 'x' * length;
          final result = await store.prepare(raw);
          expect(result.modelResult, raw);
          expect(result.outputId, isNull);
        }
      });

      test(
        'large single line can be reconstructed exactly across Unicode pages',
        () async {
          final raw = '开头\n${'a中😀' * 30000}\n末尾';
          final result = await store.prepare(raw);
          final id = result.outputId!;
          final preview = String.fromCharCodes(
            raw.runes.take(ToolOutputStore.previewLimit),
          );
          expect(result.modelResult, endsWith(preview));
          expect(
            result.modelResult,
            contains('offset=${ToolOutputStore.previewLimit}'),
          );
          expect(
            result.modelResult.length,
            lessThan(ToolOutputStore.inlineLimit),
          );
          final reconstructed = StringBuffer(preview);
          var offset = ToolOutputStore.previewLimit;
          while (true) {
            final page = await store.read(id, offset: offset, limit: 997);
            reconstructed.write(page.text);
            expect(page.nextOffset, offset + page.text.runes.length);
            offset = page.nextOffset;
            if (!page.hasMore) break;
          }
          expect(reconstructed.toString(), raw);
          expect((await store.read(id, offset: offset)).text, isEmpty);
          expect((await store.read(id, offset: offset)).hasMore, isFalse);
        },
      );

      test('parallel saves and replay use the same content ID', () async {
        final raw = 'replay' * 5000;
        final ids = await Future.wait(List.generate(8, (_) => store.save(raw)));
        expect(ids.toSet(), hasLength(1));
        final reopened = onDisk ? ToolOutputStore(directory: directory) : store;
        expect(
          (await reopened.read(ids.first, offset: 123, limit: 50)).text,
          raw.substring(123, 173),
        );
        final prepared = await reopened.prepare(raw);
        final reference = await reopened.reference(prepared.modelResult);
        expect(reference, contains(ids.first));
        expect(reference, contains('offset=0'));
      });

      test('read tool is read-only and gives continuous offsets', () async {
        final id = await store.save('abcdefghijkl');
        final tool = ToolOutputReadTool(store);
        expect(tool.risk, ToolRisk.readOnly);
        expect(tool.executionMode, ExecutionMode.parallel);
        final first = await tool.execute({'output_id': id, 'limit': 5});
        expect(first, contains('offset=5'));
        expect(first, endsWith('abcde'));
        final last = await tool.execute({'output_id': id, 'offset': 5});
        expect(last, contains('End of saved output.'));
        expect(last, endsWith('fghijkl'));
        for (final args in [
          {'output_id': '../../some-file'},
          {'output_id': id, 'offset': -1},
          {'output_id': id, 'limit': 0},
          {'output_id': id, 'limit': ToolOutputStore.pageLimit + 1},
          {'output_id': '0' * 64},
        ]) {
          expect(await tool.execute(args), startsWith('Error:'));
        }
      });
    });
  }
}
