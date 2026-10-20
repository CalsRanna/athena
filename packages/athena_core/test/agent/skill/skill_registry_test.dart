import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:test/test.dart';

/// 一级目录是每次 run 都进 system prompt 的块：顺序只要抖动一次，prompt
/// prefix cache 就整段失效。这里锁住「顺序由持久化信号决定」而不是由
/// 文件系统枚举顺序决定。
void main() {
  late Directory root;
  late SkillRegistry registry;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_skill_registry_');
    for (final name in ['alpha', 'beta', 'gamma']) {
      Directory(
        '${root.path}/.athena/skills/$name',
      ).createSync(recursive: true);
      SkillLoader().saveSkill(
        name: name,
        description: 'skill $name',
        body: 'body of $name',
        targetDir: '${root.path}/.athena/skills/$name',
      );
    }
    registry = SkillRegistry()..loadAll(homeDir: root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// 从一级目录里按出现顺序解析技能名。
  List<String> listedOrder(SkillRegistry r) {
    final prompt = r.level1Prompt;
    return [
      for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(prompt))
        match.group(1)!,
    ];
  }

  test('没有访问记录时按名称排序，而不是文件枚举顺序', () {
    final first = registry.level1Prompt;
    final second = (SkillRegistry()..loadAll(homeDir: root.path)).level1Prompt;

    expect(first, second, reason: '两次加载必须逐字节一致');
    expect(listedOrder(registry), [
      'alpha',
      'beta',
      'gamma',
    ], reason: '无访问信号时用名称定序，保证跨重启稳定');
  });

  test('访问过的技能排到最前面，且重启后顺序保持', () {
    registry.get('gamma');

    expect(listedOrder(registry).first, 'gamma');

    // 新建实例模拟重启：访问时间来自磁盘，顺序不应回到名称序。
    final restarted = SkillRegistry()..loadAll(homeDir: root.path);
    expect(listedOrder(restarted).first, 'gamma');
    expect(restarted.level1Prompt, registry.level1Prompt);
  });

  test('访问时间只保留当前存在的用户技能', () {
    registry.get('gamma');
    registry.get('alpha');
    final usage = File('${root.path}/.athena/skills/.usage.json');
    expect(usage.existsSync(), isTrue);
    expect(usage.readAsStringSync(), contains('gamma'));

    registry.deleteSkill('alpha');
    registry.deleteSkill('gamma');

    expect(usage.readAsStringSync(), isNot(contains('gamma')));
  });

  test('超过 20 条时按最近使用截断，提示剩余数量', () {
    for (var i = 0; i < 25; i++) {
      final name = 'skill-$i';
      Directory(
        '${root.path}/.athena/skills/$name',
      ).createSync(recursive: true);
      SkillLoader().saveSkill(
        name: name,
        description: 'd',
        body: 'b',
        targetDir: '${root.path}/.athena/skills/$name',
      );
    }
    final fresh = SkillRegistry()..loadAll(homeDir: root.path);
    fresh.get('skill-7');

    final prompt = fresh.level1Prompt;

    expect(prompt, contains('**skill-7**'));
    expect(prompt, contains('另有'));
    expect('- **'.allMatches(prompt).length, SkillRegistry.maxLevel1Skills);
  });

  test('损坏的使用记录不影响技能加载', () {
    File(
      '${root.path}/.athena/skills/.usage.json',
    ).writeAsStringSync('{ not json');

    final loaded = SkillRegistry()..loadAll(homeDir: root.path);

    expect(loaded.all, hasLength(3));
    expect(listedOrder(loaded), ['alpha', 'beta', 'gamma']);
  });
}
