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

  group('SkillRegistry isToolAllowed', () {
    _TestRegistry buildRegistryWithSkill({
      required String name,
      String? allowedTools,
    }) {
      final t = Directory.systemTemp.createTempSync('skill_test_');
      addTearDown(() {
        if (t.existsSync()) t.deleteSync(recursive: true);
      });
      final dir = Directory('${t.path}/$name')..createSync();
      final allowedLine =
          allowedTools == null ? '' : 'allowed-tools: $allowedTools\n';
      File('${dir.path}/SKILL.md').writeAsStringSync(
        '---\nname: $name\ndescription: x\n$allowedLine---\nbody\n',
      );
      final skills = SkillLoader().loadFromDirectory(t.path);
      return _TestRegistry(skills.isNotEmpty ? skills.first : null);
    }

    test('outside skill context returns false', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      expect(reg.isToolAllowed('file_read'), isFalse);
    });

    test('allowed tool in skill context returns true', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(reg.isToolAllowed('file_read'), isTrue);
    });

    test('disallowed tool in skill context returns false', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(reg.isToolAllowed('bash'), isFalse);
    });

    test('skill without allowed-tools returns false for all', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: null);
      reg.pushContext('a');
      expect(reg.isToolAllowed('bash'), isFalse);
      expect(reg.isToolAllowed('file_read'), isFalse);
    });

    test('skill tool itself is always allowed', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(reg.isToolAllowed('skill'), isTrue);
    });

    test('multiple comma-separated entries', () {
      final reg = buildRegistryWithSkill(
        name: 'a',
        allowedTools: 'file_read, search ,bash',
      );
      reg.pushContext('a');
      expect(reg.isToolAllowed('file_read'), isTrue);
      expect(reg.isToolAllowed('bash'), isTrue);
      expect(reg.isToolAllowed('file_write'), isFalse);
    });
  });
}

/// 测试用 registry 子类：跳过 loadAll 的 IO 依赖，由构造时直接注入单个 Skill。
class _TestRegistry extends SkillRegistry {
  final Skill? _skill;
  _TestRegistry(this._skill);

  String? _stackHead;

  @override
  Skill? get(String name) => _skill?.name == name ? _skill : null;

  @override
  Skill? get currentContext => _stackHead == null ? null : get(_stackHead!);

  @override
  void pushContext(String skillName) {
    _stackHead = skillName;
  }

  @override
  void popContext() {
    _stackHead = null;
  }

  @override
  void clearContext() {
    _stackHead = null;
  }
}
