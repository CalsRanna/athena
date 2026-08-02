import 'package:athena/agent/permission/permission_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionRule', () {
    test('matches by tool and prefix', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'git ');
      expect(rule.matches('bash', 'git status'), isTrue);
      expect(rule.matches('bash', 'git log --oneline'), isTrue);
      expect(rule.matches('bash', 'ls'), isFalse);
      expect(rule.matches('powershell', 'git status'), isFalse);
    });

    test('empty pattern matches all for that tool', () {
      final rule = PermissionRule(tool: 'web_search');
      expect(rule.matches('web_search', null), isTrue);
      expect(rule.matches('web_search', 'any query'), isTrue);
      expect(rule.matches('file_read', 'anything'), isFalse);
    });

    test('null keyArg returns false when pattern is non-empty', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'git');
      expect(rule.matches('bash', null), isFalse);
    });

    test('toJson/fromJson roundtrip', () {
      final rule = PermissionRule(tool: 'file_read', pattern: '/a/b/');
      final json = rule.toJson();
      expect(json['tool'], 'file_read');
      expect(json['pattern'], '/a/b/');

      final restored = PermissionRule.fromJson(json);
      expect(restored.tool, 'file_read');
      expect(restored.pattern, '/a/b/');
    });

    test('fromJson handles missing pattern', () {
      final rule = PermissionRule.fromJson({'tool': 'bash'});
      expect(rule.tool, 'bash');
      expect(rule.pattern, '');
    });

    test('multiple rules can coexist', () {
      final store = PermissionStore();
      store.rules.add(PermissionRule(tool: 'bash', pattern: 'git '));
      store.rules.add(PermissionRule(tool: 'file_read', pattern: '/tmp/'));

      // Matching is not store responsibility, just check rules are separate
      expect(store.rules.length, 2);
      expect(store.rules[0].matches('bash', 'git status'), isTrue);
      expect(store.rules[1].matches('file_read', '/tmp/data.txt'), isTrue);
    });

    test('action-level rule matches by action', () {
      final rule = PermissionRule(tool: 'bash', action: 'git');
      expect(rule.matches('bash', 'git status', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git push', action: 'git'), isTrue);
      // 动作不一致不匹配
      expect(rule.matches('bash', 'git status', action: 'npm'), isFalse);
      // 调用方未提供动作不匹配
      expect(rule.matches('bash', 'git status'), isFalse);
      // 其他工具不匹配
      expect(rule.matches('powershell', 'git status', action: 'git'), isFalse);
    });

    test('action-level rule with pattern narrows arguments', () {
      final rule = PermissionRule(
        tool: 'bash',
        action: 'git',
        pattern: 'status*',
      );
      // pattern 匹配剥离动作后的参数部分
      expect(rule.matches('bash', 'git status -s', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git status --short', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git push', action: 'git'), isFalse);
    });

    test('action serialized and restored in json', () {
      final rule = PermissionRule(tool: 'bash', action: 'git', pattern: '*');
      final json = rule.toJson();
      expect(json['action'], 'git');

      final restored = PermissionRule.fromJson(json);
      expect(restored.action, 'git');
      expect(restored.pattern, '*');
    });
  });
}
