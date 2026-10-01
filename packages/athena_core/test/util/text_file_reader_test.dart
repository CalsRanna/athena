import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/util/text_file_reader.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_text_reader_');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'later pages reuse an index and seek rather than rescan the file',
    () async {
      final file = File('${root.path}/large.txt')
        ..writeAsStringSync('${'x' * 999}\n' * 6000);
      final observed = _ObservedFile(file);
      final reader = TextFileReader();
      final first = await reader.read(observed, offset: 5500, limit: 2);
      expect(first, contains('[lines 5501-5502 / 6000 total]'));
      observed.starts.clear();
      observed.bytesRead = 0;
      final next = await reader.read(observed, offset: 5502, limit: 2);
      expect(next, contains('[lines 5503-5504 / 6000 total]'));
      expect(observed.starts.single, greaterThan(0));
      expect(observed.bytesRead, lessThan(500000));

      file.writeAsStringSync('${'y' * 999}\n' * 6000);
      file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));
      observed.starts.clear();
      final changed = await reader.read(observed, offset: 5502, limit: 2);
      expect(changed, contains('y' * 999));
      expect(observed.starts.first, 0);
    },
  );

  test(
    'CR-only and CRLF files use the same line count as LineSplitter',
    () async {
      final cr = File('${root.path}/cr.txt')
        ..writeAsStringSync('x\r' * (3 * 1024 * 1024));
      final reader = TextFileReader();
      final last = await reader.read(cr, offset: 3 * 1024 * 1024 - 1, limit: 1);
      expect(last, contains('/ ${3 * 1024 * 1024} total]'));
      expect(last, endsWith('\tx\n'));
      final crlf = File('${root.path}/crlf.txt')
        ..writeAsStringSync('${'x' * 65535}\r\n' * 82);
      final page = await reader.read(crlf, offset: 81, limit: 1);
      expect(page, contains('[lines 82-82 / 82 total]'));
      expect(page, endsWith('${'x' * 65535}\n'));
    },
  );

  test(
    'a huge single line fails explicitly instead of buffering without a bound',
    () async {
      final file = File('${root.path}/single.json')
        ..writeAsStringSync('x' * (6 * 1024 * 1024));
      await expectLater(
        TextFileReader().read(file, limit: 1),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('cancellation interrupts index construction', () async {
    final file = File('${root.path}/cancel.txt')
      ..writeAsStringSync('x\n' * (3 * 1024 * 1024));
    final cancel = Completer<void>()..complete();
    await expectLater(
      TextFileReader().read(file, cancelSignal: cancel.future),
      throwsA(isA<CancelledException>()),
    );
  });
}

class _ObservedFile implements File {
  _ObservedFile(this.file);
  final File file;
  final List<int> starts = [];
  int bytesRead = 0;
  @override
  String get path => file.path;
  @override
  Future<FileStat> stat() => file.stat();
  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    starts.add(start ?? 0);
    return file.openRead(start, end).map((bytes) {
      bytesRead += bytes.length;
      return bytes;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
