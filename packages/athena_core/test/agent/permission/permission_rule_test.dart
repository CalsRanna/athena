import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:test/test.dart';

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

  group('Always Allow flow (规则由 parseRulePattern(keyArg) 生成)', () {
    // 与 AgentRunCoordinator._askPermission 的生成方式保持一致。
    PermissionRule buildShellRule(String command) {
      final parsed = CommandAnalyzer.parseRulePattern(command);
      return PermissionRule(
        tool: 'bash',
        action: parsed.action,
        pattern: parsed.pattern,
      );
    }

    test('bare command matches itself, not unrelated variants', () {
      final rule = buildShellRule('git status');
      // 回归：被记忆的命令本身必须放行（此前追加 " *" 导致只有
      // git status -s 这类带参变体命中，git status 本身反而弹窗）
      expect(rule.matches('bash', 'git status', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git status -s', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git push', action: 'git'), isFalse);
    });

    test('command with args matches itself and supersets, not partial prefixes',
        () {
      final rule = buildShellRule('git push origin main');
      expect(
          rule.matches('bash', 'git push origin main', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git push origin main -f', action: 'git'),
          isTrue);
      expect(rule.matches('bash', 'git push origin', action: 'git'), isFalse);
      expect(rule.matches('bash', 'git push', action: 'git'), isFalse);
    });

    test('bare action with no args allows all commands of that action', () {
      final rule = buildShellRule('dart');
      expect(rule.matches('bash', 'dart run main.dart', action: 'dart'),
          isTrue);
      expect(rule.matches('bash', 'dart format .', action: 'dart'), isTrue);
    });
  });
}
