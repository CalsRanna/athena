import 'dart:io';

import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 在 `<root>/.athena/skills/<name>/SKILL.md` 写入一个 skill。
  void writeSkill(
    String root,
    String name, {
    String description = 'x',
    String? allowedTools,
  }) {
    final dir = Directory('$root/.athena/skills/$name')
      ..createSync(recursive: true);
    final allowedLine =
        allowedTools == null ? '' : 'allowed-tools: $allowedTools\n';
    File('${dir.path}/SKILL.md').writeAsStringSync(
      '---\nname: $name\ndescription: $description\n$allowedLine---\nbody\n',
    );
  }

  group('SkillTrustStore', () {
    late Directory tmp;
    late File trustFile;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('skill_trust_store_test_');
      trustFile = File('${tmp.path}/trusted_skill_dirs.json');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('isTrusted false before, true after trust, and persists', () async {
      final store = SkillTrustStore(file: trustFile);
      final dir = '${tmp.path}/projectA';
      expect(store.isTrusted(dir), isFalse);

      await store.trust(dir);
      expect(store.isTrusted(dir), isTrue);

      // 一个全新的、指向相同文件的 store 也应识别为已信任（持久化）。
      final fresh = SkillTrustStore(file: trustFile);
      expect(fresh.isTrusted(dir), isTrue);
    });

    test('trailing slash equivalence', () async {
      final store = SkillTrustStore(file: trustFile);
      await store.trust('${tmp.path}/x/y');
      expect(store.isTrusted('${tmp.path}/x/y/'), isTrue);
    });

    test('missing file treated as empty set (no throw)', () {
      final store = SkillTrustStore(file: trustFile);
      expect(store.isTrusted('${tmp.path}/anything'), isFalse);
    });

    test('corrupt file treated as empty set (no throw)', () {
      trustFile.writeAsStringSync('{ not valid json');
      final store = SkillTrustStore(file: trustFile);
      expect(store.isTrusted('${tmp.path}/anything'), isFalse);
    });
  });

  group('SkillRegistry project trust', () {
    late Directory homeDir;
    late Directory projectDir;
    late File trustFile;

    setUp(() {
      homeDir = Directory.systemTemp.createTempSync('skill_trust_home_');
      projectDir = Directory.systemTemp.createTempSync('skill_trust_proj_');
      trustFile = File(
        '${Directory.systemTemp.createTempSync('skill_trust_file_').path}/'
        'trusted_skill_dirs.json',
      );
    });

    tearDown(() {
      if (homeDir.existsSync()) homeDir.deleteSync(recursive: true);
      if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
      final fileParent = trustFile.parent;
      if (fileParent.existsSync()) fileParent.deleteSync(recursive: true);
    });

    SkillRegistry buildRegistry() =>
        SkillRegistry(trustStore: SkillTrustStore(file: trustFile));

    test('untrusted project skills are inert', () {
      writeSkill(homeDir.path, 'alpha');
      writeSkill(projectDir.path, 'beta');

      final reg = buildRegistry();
      reg.loadAll(homeDir: homeDir.path, projectDir: projectDir.path);

      expect(reg.get('alpha'), isNotNull);
      expect(reg.get('beta'), isNull);
      expect(reg.all.map((s) => s.name), ['alpha']);
      expect(reg.level1Prompt, contains('alpha'));
      expect(reg.level1Prompt, isNot(contains('beta')));
      expect(reg.hasPendingProjectSkills, isTrue);
      expect(reg.pendingProjectSkills.map((s) => s.name), contains('beta'));
      // 规范化相等（projectDir 末尾无斜杠）。
      expect(reg.pendingProjectDir, projectDir.path);
    });

    test('untrusted project skill does NOT override user skill', () {
      writeSkill(homeDir.path, 'shared', description: 'USER');
      writeSkill(projectDir.path, 'shared', description: 'PROJECT');

      final reg = buildRegistry();
      reg.loadAll(homeDir: homeDir.path, projectDir: projectDir.path);

      expect(reg.get('shared')!.description, 'USER');
    });

    test('trustCurrentProject activates and persists', () async {
      writeSkill(homeDir.path, 'alpha');
      writeSkill(homeDir.path, 'shared', description: 'USER');
      writeSkill(projectDir.path, 'beta');
      writeSkill(projectDir.path, 'shared', description: 'PROJECT');

      final reg = buildRegistry();
      reg.loadAll(homeDir: homeDir.path, projectDir: projectDir.path);

      // 信任前：beta 不可见，shared 仍为 USER。
      expect(reg.get('beta'), isNull);
      expect(reg.get('shared')!.description, 'USER');

      await reg.trustCurrentProject();

      expect(reg.get('beta'), isNotNull);
      expect(reg.get('shared')!.description, 'PROJECT');
      expect(reg.hasPendingProjectSkills, isFalse);
      expect(reg.pendingProjectDir, isNull);

      // 信任已持久化到文件。
      expect(trustFile.existsSync(), isTrue);
      expect(trustFile.readAsStringSync(), contains(projectDir.path));

      // 全新 registry（指向同一文件）应一开始就让 beta 处于激活状态。
      final fresh = SkillRegistry(trustStore: SkillTrustStore(file: trustFile));
      fresh.loadAll(homeDir: homeDir.path, projectDir: projectDir.path);
      expect(fresh.get('beta'), isNotNull);
      expect(fresh.hasPendingProjectSkills, isFalse);
      expect(fresh.get('shared')!.description, 'PROJECT');
    });

    test('project dir equal to home dir: no pending, loaded once', () {
      writeSkill(homeDir.path, 'alpha');

      final reg = buildRegistry();
      reg.loadAll(homeDir: homeDir.path, projectDir: homeDir.path);

      expect(reg.get('alpha'), isNotNull);
      expect(reg.all.map((s) => s.name), ['alpha']);
      expect(reg.hasPendingProjectSkills, isFalse);
      expect(reg.pendingProjectDir, isNull);
    });

    test('trustCurrentProject is a no-op when nothing pending', () async {
      writeSkill(homeDir.path, 'alpha');

      final reg = buildRegistry();
      reg.loadAll(homeDir: homeDir.path, projectDir: homeDir.path);

      await reg.trustCurrentProject();
      expect(reg.hasPendingProjectSkills, isFalse);
      expect(reg.get('alpha'), isNotNull);
    });
  });
}
