import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:test/test.dart';

void main() {
  group('SkillLoader name validation', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('skill_loader_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    void writeSkill(String dirName, String name, {String? description}) {
      final dir = Directory('${tmp.path}/$dirName')..createSync();
      final desc = description ?? 'Test skill';
      File('${dir.path}/SKILL.md').writeAsStringSync(
        '---\nname: "$name"\ndescription: $desc\n---\nbody\n',
      );
    }

    test('accepts plain alphanumeric name', () {
      writeSkill('a', 'code-reviewer');
      final skills = SkillLoader().loadFromDirectory(tmp.path);
      expect(skills, hasLength(1));
      expect(skills.first.name, 'code-reviewer');
    });

    test('rejects name with forward slash', () {
      writeSkill('a', 'foo/bar');
      expect(SkillLoader().loadFromDirectory(tmp.path), isEmpty);
    });

    test('rejects name with backslash', () {
      writeSkill('a', r'foo\bar');
      expect(SkillLoader().loadFromDirectory(tmp.path), isEmpty);
    });

    test('rejects name with control character', () {
      writeSkill('a', 'foo\u0001bar');
      expect(SkillLoader().loadFromDirectory(tmp.path), isEmpty);
    });

    test('rejects name "." and ".."', () {
      writeSkill('a', '.');
      writeSkill('b', '..');
      expect(SkillLoader().loadFromDirectory(tmp.path), isEmpty);
    });

    test('rejects oversized name (>64 chars)', () {
      writeSkill('a', 'x' * 65);
      expect(SkillLoader().loadFromDirectory(tmp.path), isEmpty);
    });
  });

  group('SkillRegistry context stack', () {
    test('pushContext on unknown skill returns null currentContext', () {
      final registry = SkillRegistry();
      registry.pushContext('unknown');
      expect(registry.currentContext, isNull);
      registry.popContext();
    });

    test('popContext on empty stack is a no-op', () {
      final registry = SkillRegistry();
      registry.popContext();
      registry.popContext();
      expect(registry.currentContext, isNull);
    });

    test('clearContext empties the stack', () {
      final registry = SkillRegistry();
      registry.pushContext('a');
      registry.pushContext('b');
      registry.clearContext();
      expect(registry.currentContext, isNull);
    });
  });

  group('SkillLoader.saveSkill', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('skill_save_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('写入后可被 loadFromDirectory 解析（round trip）', () {
      SkillLoader().saveSkill(
        name: 'demo',
        description: 'A demo skill',
        body: '## Steps\n\n1. Do it.',
        targetDir: '${tmp.path}/demo',
      );

      final skills = SkillLoader().loadFromDirectory(tmp.path);
      expect(skills, hasLength(1));
      final skill = skills.single;
      expect(skill.name, 'demo');
      expect(skill.description, 'A demo skill');
      expect(skill.body, contains('Do it.'));
    });

    test('description 含冒号/引号/换行时仍可解析', () {
      const description = 'Uses: colons, "quotes"\nand newlines # hash';
      SkillLoader().saveSkill(
        name: 'tricky',
        description: description,
        body: 'body',
        targetDir: '${tmp.path}/tricky',
      );

      final skill = SkillLoader().loadFromDirectory(tmp.path).single;
      expect(skill.description, description);
    });
  });

  group('SkillLoader legacy frontmatter', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('skill_legacy_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test(
      '带已移除的 allowed-tools / disable-model-invocation 字段的旧文件仍可解析，保存后这些行消失',
      () {
        final dir = Directory('${tmp.path}/legacy')
          ..createSync(recursive: true);
        final file = File('${dir.path}/SKILL.md');
        file.writeAsStringSync(
          '---\n'
          'name: "legacy"\n'
          'description: "old skill"\n'
          'allowed-tools: file_read, web_search\n'
          'disable-model-invocation: false\n'
          '---\n'
          'body\n',
        );

        final skill = SkillLoader().parseSkillFile(file);
        expect(skill, isNotNull);
        expect(skill!.name, 'legacy');
        expect(skill.description, 'old skill');
        expect(skill.body, 'body');

        SkillLoader().saveSkill(
          name: skill.name,
          description: skill.description,
          body: skill.body,
          targetDir: dir.path,
        );
        expect(file.readAsStringSync(), isNot(contains('allowed-tools')));
        expect(
          file.readAsStringSync(),
          isNot(contains('disable-model-invocation')),
        );
      },
    );
  });

  group('SkillLoader.isValidSkillName', () {
    test('接受 kebab-case，拒绝路径分隔符与控制字符', () {
      expect(SkillLoader.isValidSkillName('code-reviewer'), isTrue);
      expect(SkillLoader.isValidSkillName('foo/bar'), isFalse);
      expect(SkillLoader.isValidSkillName('../escape'), isFalse);
      expect(SkillLoader.isValidSkillName(''), isFalse);
    });
  });
}
