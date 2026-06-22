import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:flutter_test/flutter_test.dart';

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

}
