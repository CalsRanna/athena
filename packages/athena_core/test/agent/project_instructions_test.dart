import 'dart:io';

import 'package:athena_core/agent/project_instructions.dart';
import 'package:test/test.dart';

/// 约定文件是用户手工维护的仓库文件：这里覆盖「读进来 / 不注入空段 /
/// 变化才刷新」三条对外契约。
void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('athena_agents_md_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  File agentsFile() =>
      File('${workspace.path}${Platform.pathSeparator}AGENTS.md');

  group('ProjectInstructions.load', () {
    test('读取工作文件夹根目录的 AGENTS.md', () {
      agentsFile().writeAsStringSync('# 约定\n\n先跑测试。\n');

      final instructions = ProjectInstructions.load(workspace.path);

      expect(instructions, isNotNull);
      expect(instructions!.content, contains('先跑测试'));
      expect(instructions.size, greaterThan(0));
      expect(instructions.modifiedMillis, greaterThan(0));
      // 注入文本带来源说明，模型才知道这段是什么、来自哪里。
      expect(instructions.prompt, contains(instructions.path));
      expect(instructions.prompt, contains('先跑测试'));
    });

    test('未指定工作文件夹时不读取', () {
      expect(ProjectInstructions.load(null), isNull);
      expect(ProjectInstructions.load(''), isNull);
    });

    test('文件不存在时返回 null，不注入空段', () {
      expect(ProjectInstructions.load(workspace.path), isNull);
    });

    test('内容只有空白时返回 null', () {
      agentsFile().writeAsStringSync('  \n\t\n');
      expect(ProjectInstructions.load(workspace.path), isNull);
    });
  });

  group('ProjectInstructions.refresh', () {
    test('文件未变化时返回 null（不重复替换已注入的块）', () {
      agentsFile().writeAsStringSync('# 约定\n');
      final instructions = ProjectInstructions.load(workspace.path)!;

      expect(instructions.refresh(), isNull);
    });

    test('内容变化时返回新快照', () {
      agentsFile().writeAsStringSync('旧约定：先跑测试。\n');
      final instructions = ProjectInstructions.load(workspace.path)!;

      agentsFile().writeAsStringSync('新约定：先跑分析，再跑测试，最后看差异。\n');
      final updated = instructions.refresh();

      expect(updated, isNotNull);
      expect(updated!.content, contains('新约定'));
      expect(updated.prompt, contains('新约定'));
    });

    test('只有字节数变化也视为变化（同 mtime 场景）', () {
      agentsFile().writeAsStringSync('短\n');
      final instructions = ProjectInstructions.load(workspace.path)!;

      // 把 mtime 拨回读取时的值，逼出「只看 mtime 会漏判」的路径。
      agentsFile().writeAsStringSync('长一些的内容\n');
      agentsFile().setLastModifiedSync(
        DateTime.fromMillisecondsSinceEpoch(instructions.modifiedMillis),
      );

      final updated = instructions.refresh();
      expect(updated, isNotNull);
      expect(updated!.content, contains('长一些的内容'));
    });

    test('文件被删除或清空时返回 null（保留已注入内容）', () {
      agentsFile().writeAsStringSync('# 约定\n');
      final instructions = ProjectInstructions.load(workspace.path)!;

      agentsFile().deleteSync();
      expect(instructions.refresh(), isNull);

      agentsFile().writeAsStringSync('\n \n');
      expect(instructions.refresh(), isNull);
    });
  });
}
