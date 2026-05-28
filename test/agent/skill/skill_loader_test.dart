import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_interface.dart';
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
      // SKILL.md 的 YAML 部分用引号包名字，保证控制字符不会破坏解析。
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
      writeSkill('a', 'foobar');
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

  group('SkillRegistry.effectiveDangerLevel', () {
    _TestRegistry buildRegistryWithSkill({
      required String name,
      String? allowedTools,
    }) {
      final tmp = Directory.systemTemp.createTempSync('skill_eff_test_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final dir = Directory('${tmp.path}/$name')..createSync();
      final allowedLine =
          allowedTools == null ? '' : 'allowed-tools: $allowedTools\n';
      File('${dir.path}/SKILL.md').writeAsStringSync(
        '---\nname: $name\ndescription: x\n$allowedLine---\nbody\n',
      );
      final skills = SkillLoader().loadFromDirectory(tmp.path);
      return _TestRegistry(skills.isNotEmpty ? skills.first : null);
    }

    test('outside skill context returns default level', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      expect(
        reg.effectiveDangerLevel('bash', DangerLevel.needsApproval),
        DangerLevel.needsApproval,
      );
      expect(
        reg.effectiveDangerLevel('file_read', DangerLevel.safe),
        DangerLevel.safe,
      );
    });

    test('allowed tool in skill context downgrades to safe', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('file_read', DangerLevel.needsApproval),
        DangerLevel.safe,
      );
    });

    test('disallowed tool in skill context forced to needsApproval', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('bash', DangerLevel.safe),
        DangerLevel.needsApproval,
      );
      expect(
        reg.effectiveDangerLevel('bash', DangerLevel.needsApproval),
        DangerLevel.needsApproval,
      );
    });

    test('skill without allowed-tools field keeps defaults', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: null);
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('bash', DangerLevel.needsApproval),
        DangerLevel.needsApproval,
      );
      expect(
        reg.effectiveDangerLevel('file_read', DangerLevel.safe),
        DangerLevel.safe,
      );
    });

    test('forbidden tool never gets relaxed', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'bash');
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('bash', DangerLevel.forbidden),
        DangerLevel.forbidden,
      );
    });

    test('skill tool itself is never restricted by current context', () {
      final reg = buildRegistryWithSkill(name: 'a', allowedTools: 'file_read');
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('skill', DangerLevel.safe),
        DangerLevel.safe,
      );
    });

    test('allowed-tools with multiple comma-separated entries', () {
      final reg = buildRegistryWithSkill(
        name: 'a',
        allowedTools: 'file_read, search ,bash',
      );
      reg.pushContext('a');
      expect(
        reg.effectiveDangerLevel('search', DangerLevel.needsApproval),
        DangerLevel.safe,
      );
      expect(
        reg.effectiveDangerLevel('file_write', DangerLevel.needsApproval),
        DangerLevel.needsApproval,
      );
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
