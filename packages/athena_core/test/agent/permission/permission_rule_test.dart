import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:test/test.dart';

/// 「始终允许」落库形态的边界用例。
///
/// shell 工具落 [RuleKind.exact]（整条命令精确匹配），不再落
/// action（动作 + 参数前缀）。后者会把一次授权顺带扩展到用户
/// 没看到的变体：`npm test` 的授权会放行 `npm test -- --watch`，
/// `rm -rf build` 的授权会放行 `rm -rf build -f`，而这两次都没有二次确认。
/// 旧 action 规则不再生效,避免通过命令分析扩展授权。
void main() {
  group('shell 落整条命令的 exact', () {
    test('单条命令 → exact，pattern 为完整命令', () {
      final rules = PermissionRule.forToolCall('bash', 'rm -rf build');
      expect(rules, hasLength(1));
      expect(rules.single.kind, RuleKind.exact);
      expect(rules.single.pattern, 'rm -rf build');
    });

    test('复合命令不被拆成多条子命令规则', () {
      final rules = PermissionRule.forToolCall(
        'bash',
        'git status && npm test',
      );
      expect(rules, hasLength(1));
      expect(rules.single.kind, RuleKind.exact);
      expect(rules.single.pattern, 'git status && npm test');
    });

    test('powershell 同样落 exact', () {
      final rules = PermissionRule.forToolCall('powershell', 'Remove-Item x');
      expect(rules, hasLength(1));
      expect(rules.single.kind, RuleKind.exact);
    });

    test('任何命令都不再落 action 规则（回归护栏）', () {
      for (final command in [
        'rm -rf build',
        'npm test -- --watch',
        'git clean -xfd',
        'find . -delete',
        'sudo rm -rf /',
      ]) {
        final rules = PermissionRule.forToolCall('bash', command);
        expect(
          rules.single.kind,
          RuleKind.exact,
          reason: command,
        );
      }
    });
  });

  group('exact 规则的匹配范围', () {
    final rule = PermissionRule.forToolCall('bash', 'rm -rf build').single;

    test('完全相同的命令命中', () {
      expect(rule.matches('bash', 'rm -rf build'), isTrue);
    });

    test('加参数的变体不命中（旧的 action 前缀规则会命中）', () {
      expect(rule.matches('bash', 'rm -rf build -f'), isFalse);
    });

    test('同前缀的子路径不命中', () {
      expect(rule.matches('bash', 'rm -rf build/src'), isFalse);
    });

    test('另一条命令不命中', () {
      expect(rule.matches('bash', 'rm -rf dist'), isFalse);
    });

    test('工具名不同的调用不命中', () {
      expect(rule.matches('powershell', 'rm -rf build'), isFalse);
    });
  });

  group('其余工具的落库形态不变', () {
    test('文件工具 → path 规则', () {
      final rules = PermissionRule.forToolCall('file_write', '/tmp/notes.md');
      expect(rules.single.kind, RuleKind.path);
      expect(rules.single.pattern, '/tmp/notes.md');
    });

    test('web_fetch → origin 规则', () {
      final rules = PermissionRule.forToolCall(
        'web_fetch',
        'https://a.com/x',
      );
      expect(rules.single.kind, RuleKind.origin);
    });

    test('keyArg 缺失 → 空 pattern 的 exact，放行该工具全部调用', () {
      final rules = PermissionRule.forToolCall('bash', null);
      expect(rules.single.kind, RuleKind.exact);
      expect(rules.single.pattern, '');
      expect(rules.single.matches('bash', 'anything'), isTrue);
    });
  });

  group('持久规则读取', () {
    test('旧 action 规则停止生效,不再解析命令动作或参数前缀', () {
      for (final effect in RuleEffect.values) {
        final legacy = PermissionRule.fromJson({
          'tool': 'bash',
          'kind': 'action',
          'action': 'git',
          'pattern': 'status',
          'effect': effect.name,
        });
        expect(legacy, isNull);
      }
    });

    test('现有 exact、path、origin 规则仍可往返序列化', () {
      for (final rule in [
        PermissionRule.forToolCall('bash', 'npm test').single,
        PermissionRule.forToolCall('file_write', '/tmp/*.txt').single,
        PermissionRule.forToolCall('web_fetch', 'https://a.com').single,
        const PermissionRule(
          tool: 'bash',
          kind: RuleKind.exact,
          pattern: 'npm test',
          effect: RuleEffect.deny,
        ),
      ]) {
        final decoded = PermissionRule.fromJson(rule.toJson());
        expect(decoded?.toJson(), rule.toJson());
        expect(decoded?.matches(rule.tool, rule.pattern), isTrue);
      }
    });
  });
}
