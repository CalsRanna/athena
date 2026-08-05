import 'dart:io';

import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File sampleFile;
  late FileReadTool tool;

  setUp(() async {
    tool = FileReadTool();
    tempDir = await Directory.systemTemp.createTemp('file_read_tool_test');
    sampleFile = File(p.join(tempDir.path, 'sample.txt'));
    await sampleFile.writeAsString('line1\nline2\nline3\n');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('FileReadTool basics', () {
    test('reads a file with line numbers', () async {
      final result = await tool.execute({'path': sampleFile.path});
      expect(result, contains('1\tline1'));
      expect(result, contains('3\tline3'));
      expect(result, contains('[lines 1-3 / 3 total]'));
    });

    test('returns error for missing file', () async {
      final result = await tool.execute({
        'path': p.join(tempDir.path, 'nope.txt'),
      });
      expect(result, startsWith('Error:'));
      expect(result, contains('File not found'));
    });
  });

  group('FileReadTool sensitive path block', () {
    test('blocks .ssh / .aws / .env / .athena paths', () async {
      for (final path in [
        '~/.ssh/id_rsa',
        '$tempDir/.ssh/id_rsa',
        '$tempDir/.aws/credentials',
        '$tempDir/proj/.env',
        '$tempDir/proj/.env.local',
        '$tempDir/.athena/permissions.json',
        // Windows 反斜杠形态
        '$tempDir\\.ssh\\id_ed25519',
      ]) {
        final result = await tool.execute({'path': path});
        expect(
          result,
          startsWith('Error: Blocked:'),
          reason: 'expected blocked: $path',
        );
      }
    });

    test('allows non-sensitive paths', () async {
      // 普通项目文件不受影响
      final result = await tool.execute({'path': sampleFile.path});
      expect(result, contains('1\tline1'));
    });
  });
}
