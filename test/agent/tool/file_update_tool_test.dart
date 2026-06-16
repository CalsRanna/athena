import 'dart:io';

import 'package:athena/agent/tool/file_update_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmpDir;
  late FileUpdateTool tool;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('file_update_test_');
    tool = FileUpdateTool();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  Future<File> writeFile(String name, String content) async {
    final file = File('${tmpDir.path}/$name');
    await file.writeAsString(content);
    return file;
  }

  Future<String> readFile(String name) async {
    return File('${tmpDir.path}/$name').readAsString();
  }

  // ---------- basic replacement ----------

  test('replaces single occurrence', () async {
    await writeFile('f.txt', 'hello world');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'hello',
      'new_string': 'hi',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'hi world');
  });

  test('replace_all replaces every occurrence', () async {
    await writeFile('f.txt', 'x x x');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'x',
      'new_string': 'y',
      'replace_all': true,
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'y y y');
  });

  test('replace_all false with single match succeeds', () async {
    await writeFile('f.txt', 'alpha beta');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'alpha',
      'new_string': 'gamma',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'gamma beta');
  });

  // ---------- error conditions ----------

  test('old_string not found returns error', () async {
    await writeFile('f.txt', 'hello');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'xyzzy',
      'new_string': 'nope',
    });
    expect(result, contains('not found'));
  });

  test('old_string multiple matches without replace_all returns error', () async {
    await writeFile('f.txt', 'dup dup');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'dup',
      'new_string': 'new',
    });
    expect(result, contains('appears 2 times'));
    expect(result, contains('replace_all'));
  });

  test('old_string equals new_string returns error', () async {
    await writeFile('f.txt', 'abc');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'abc',
      'new_string': 'abc',
    });
    expect(result, contains('must differ'));
  });

  test('empty old_string returns error', () async {
    await writeFile('f.txt', 'abc');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': '',
      'new_string': 'x',
    });
    expect(result, contains('must not be empty'));
  });

  test('file not found returns error', () async {
    final result = await tool.execute({
      'path': '${tmpDir.path}/nonexistent.txt',
      'old_string': 'x',
      'new_string': 'y',
    });
    expect(result, contains('File not found'));
  });

  // ---------- line-number prefix stripping ----------

  test('strips line-number prefixes from old_string', () async {
    await writeFile('f.txt', 'line1\nline2\nline3\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': '2\tline2',
      'new_string': 'LINE2',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'line1\nLINE2\nline3\n');
  });

  test('strips line-number prefix with leading spaces (cat -n style)', () async {
    await writeFile('f.txt', 'line1\nline2\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': '     2\tline2',
      'new_string': 'LINE2',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'line1\nLINE2\n');
  });

  // ---------- quote normalization ----------

  test('matches smart quotes when file has straight quotes', () async {
    await writeFile('f.txt', 'Say "hello" to me');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'Say \u201chello\u201d to me',
      'new_string': 'Say hi to me',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'Say hi to me');
  });

  test('matches smart single quotes when file has straight quotes', () async {
    await writeFile('f.txt', "it's fine");
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'it\u2019s fine',
      'new_string': 'it is fine',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'it is fine');
  });

  // ---------- deletion / newline cleanup ----------

  test('deleting a line removes the trailing newline too', () async {
    await writeFile('f.txt', 'keep\nremove\nkeep\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'remove\n',
      'new_string': '',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'keep\nkeep\n');
  });

  test('deleting without trailing newline in old_string consumes newline after',
      () async {
    await writeFile('f.txt', 'first\nsecond\nthird\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'second',
      'new_string': '',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'first\nthird\n');
  });

  // ---------- CRLF preservation ----------

  test('preserves CRLF line endings', () async {
    await writeFile('f.txt', 'a\r\nb\r\nc\r\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'b',
      'new_string': 'BB',
    });
    expect(result, contains('Successfully updated'));
    final content = await readFile('f.txt');
    expect(content, 'a\r\nBB\r\nc\r\n');
    expect(content.contains('\r\n'), isTrue);
  });

  test('preserves LF line endings when input is LF-only', () async {
    await writeFile('f.txt', 'a\nb\nc\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'b',
      'new_string': 'BB',
    });
    expect(result, contains('Successfully updated'));
    final content = await readFile('f.txt');
    expect(content, 'a\nBB\nc\n');
    expect(content.contains('\r\n'), isFalse);
  });

  // ---------- external modification detection ----------

  test('detects external modification and refuses to write', () async {
    final file = await writeFile('f.txt', 'original content here');
    final originalFut = tool.execute({
      'path': file.path,
      'old_string': 'original',
      'new_string': 'modified',
    });
    await originalFut;
    final result = await tool.execute({
      'path': file.path,
      'old_string': 'modified',
      'new_string': 'again',
    });
    expect(result, contains('Successfully updated'));
  });

  test('delete replaces with empty string', () async {
    await writeFile('f.txt', 'hello world\n');
    final result = await tool.execute({
      'path': '${tmpDir.path}/f.txt',
      'old_string': 'hello ',
      'new_string': '',
    });
    expect(result, contains('Successfully updated'));
    expect(await readFile('f.txt'), 'world\n');
  });
}
