import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionRule', () {
    test('matches by tool, rejects other tools', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'git',
      );
      expect(rule.matches('bash', 'git status', action: 'git'), isTrue);
      expect(rule.matches('bash', 'ls -la', action: 'ls'), isFalse);
      expect(rule.matches('powershell', 'git status', action: 'git'), isFalse);
    });

    test('empty pattern allows all for that tool', () {
      final rule = PermissionRule(tool: 'web_search', kind: RuleKind.exact);
      expect(rule.matches('web_search', null), isTrue);
      expect(rule.matches('web_search', 'any query'), isTrue);
      expect(rule.matches('file_read', 'anything'), isFalse);
    });

    test('null keyArg returns false when pattern is non-empty', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'git',
        pattern: 'status',
      );
      expect(rule.matches('bash', null, action: 'git'), isFalse);
    });

    test('action rule prefix matches subcommand and its variants', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'git',
        pattern: 'status',
      );
      expect(rule.matches('bash', 'git status', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git status -s', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git status --short', action: 'git'), isTrue);
      // 词边界:git statuses 不是 status 的子命令变体
      expect(rule.matches('bash', 'git statuses', action: 'git'), isFalse);
      expect(rule.matches('bash', 'git push', action: 'git'), isFalse);
    });

    test('action rule with empty pattern allows all commands of that action', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'dart',
      );
      expect(rule.matches('bash', 'dart run main.dart', action: 'dart'),
          isTrue);
      expect(rule.matches('bash', 'dart format .', action: 'dart'), isTrue);
      expect(rule.matches('bash', 'npm run build', action: 'npm'), isFalse);
    });

    test('action rule glob: * matches any text incl / , ? one char', () {
      final star = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'rm',
        pattern: '*.log',
        wildcard: true,
      );
      expect(star.matches('bash', 'rm error.log', action: 'rm'), isTrue);
      expect(star.matches('bash', 'rm access.log', action: 'rm'), isTrue);
      // 命令参数语义:* 跨 /,rm *.log 命中带路径的日志
      expect(star.matches('bash', 'rm /var/log/error.log', action: 'rm'),
          isTrue);
      expect(star.matches('bash', 'rm debug.logs', action: 'rm'), isFalse);

      final question = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'ls',
        pattern: 'file?.txt',
        wildcard: true,
      );
      expect(question.matches('bash', 'ls file1.txt', action: 'ls'), isTrue);
      expect(question.matches('bash', 'ls fileA.txt', action: 'ls'), isTrue);
      expect(question.matches('bash', 'ls file12.txt', action: 'ls'), isFalse);
    });

    test('glob with regex metacharacters matches literally, never throws', () {
      // 回归:此前 pattern 直接拼 RegExp 且只转义指定字符,含 grep 正则
      // 的命令(grep -n "foo(\|bar" 型)会让 RegExp 编译抛
      // FormatException: Unterminated group,炸掉所有 bash 调用。
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'grep',
        pattern: r'-n "AdvanceResult [a-zA-Z]*(\|int? [a-zA-Z]*(\|EventEffect"',
        wildcard: true,
      );
      // 匹配不相关命令时不再抛异常
      expect(
        () => rule.matches('bash', 'grep -n "Other"', action: 'grep'),
        returnsNormally,
      );
      // 与被记忆的命令(含 ( | [ 等字面字符)仍可命中
      expect(
        rule.matches(
          'bash',
          r'grep -n "AdvanceResult [a-zA-Z]*(\|int? [a-zA-Z]*(\|EventEffect"',
          action: 'grep',
        ),
        isTrue,
      );
      expect(rule.matches('bash', 'grep -rn "foo" lib/', action: 'grep'),
          isFalse);
    });

    test('path glob with metacharacters does not throw', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/tmp/foo(bar)/*',
      );
      expect(() => rule.matches('file_read', '/tmp/foo(bar)/x.txt'),
          returnsNormally);
      expect(rule.matches('file_read', '/tmp/foo(bar)/x.txt'), isTrue);
    });

    test('exact rule matches whole command only', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: r'cd /a && grep -n "foo(\|bar" | head',
      );
      expect(rule.matches('bash', r'cd /a && grep -n "foo(\|bar" | head'),
          isTrue);
      // 精确匹配:任何变体都不命中(复合命令无法可靠表达语义)
      expect(
        rule.matches('bash', r'cd /a && grep -n "foo(\|bar" | head -20'),
        isFalse,
      );
      expect(rule.matches('bash', 'grep -n "foo"'), isFalse);
    });

    test('origin rule matches host prefix only', () {
      final rule = PermissionRule(
        tool: 'web_fetch',
        kind: RuleKind.origin,
        pattern: 'https://a.com',
      );
      expect(rule.matches('web_fetch', 'https://a.com'), isTrue);
      expect(rule.matches('web_fetch', 'https://a.com/path'), isTrue);
      expect(rule.matches('web_fetch', 'https://a.com:8080/x'), isTrue);
      // 主机边界:后缀域名/其他 scheme/其他主机都不命中
      expect(rule.matches('web_fetch', 'https://a.com.evil.com'), isFalse);
      expect(rule.matches('web_fetch', 'http://a.com/path'), isFalse);
      expect(rule.matches('web_fetch', 'https://b.com/path'), isFalse);
    });

    test('path rule matches under allowed directory', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/Users/x/Downloads/',
      );
      expect(rule.matches('file_read', '/Users/x/Downloads/a.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Downloads/sub/c.txt'),
          isTrue);
      expect(rule.matches('file_read', '/Users/x/Other/a.txt'), isFalse);
    });

    test('path rules match regardless of trailing-slash form', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/Users/x/proj',
      );
      expect(rule.matches('file_read', '/Users/x/proj/a.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/proj'), isTrue);
      expect(rule.matches('file_read', '/Users/x/projects/a.txt'), isFalse);
    });

    test('path traversal does not escape the allowed directory', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/Users/x/proj/',
      );
      // 词法解析 .. 后落在规则目录之外,不再命中
      expect(
        rule.matches('file_read', '/Users/x/proj/../../.ssh/authorized_keys'),
        isFalse,
      );
      expect(rule.matches('file_read', '/Users/x/proj/../.env'), isFalse);
      // 目录内的路径仍命中
      expect(rule.matches('file_read', '/Users/x/proj/sub/a.txt'), isTrue);
    });

    test('toJson/fromJson roundtrip', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'git',
        pattern: 'status',
        wildcard: false,
      );
      final json = rule.toJson();
      expect(json['tool'], 'bash');
      expect(json['kind'], 'action');
      expect(json['action'], 'git');
      expect(json['pattern'], 'status');
      expect(json.containsKey('wildcard'), isFalse);

      final restored = PermissionRule.fromJson(json);
      expect(restored, isNotNull);
      expect(restored!.kind, RuleKind.action);
      expect(restored.action, 'git');
      expect(restored.pattern, 'status');
    });

    test('fromJson rejects old format and invalid combinations', () {
      // 旧格式(无 kind)与未知 kind 一律拒绝
      expect(PermissionRule.fromJson({'tool': 'bash', 'pattern': 'git '}),
          isNull);
      expect(PermissionRule.fromJson({'tool': 'bash', 'kind': 'unknown'}),
          isNull);
      // kind 与工具组合校验
      expect(
        PermissionRule.fromJson({
          'tool': 'file_read',
          'kind': 'action',
          'action': 'git',
        }),
        isNull,
      );
      expect(
        PermissionRule.fromJson({'tool': 'bash', 'kind': 'path'}),
        isNull,
      );
      expect(
        PermissionRule.fromJson({'tool': 'file_read', 'kind': 'origin'}),
        isNull,
      );
      // action 规则缺 action
      expect(
        PermissionRule.fromJson({'tool': 'bash', 'kind': 'action'}),
        isNull,
      );
      // wildcard 仅对 action 规则有意义
      expect(
        PermissionRule.fromJson({
          'tool': 'bash',
          'kind': 'exact',
          'pattern': 'x',
          'wildcard': true,
        }),
        isNull,
      );
    });
  });

  group('PermissionRule.fromCommand (「始终允许」落库)', () {
    test('simple command → single action rule', () {
      final rules = PermissionRule.fromCommand('bash', 'git status');
      expect(rules, hasLength(1));
      final rule = rules.first;
      expect(rule.kind, RuleKind.action);
      expect(rule.action, 'git');
      expect(rule.pattern, 'status');
      expect(rule.wildcard, isFalse);
      // 变体放行、不相干命令不放行
      expect(rule.matches('bash', 'git status -s', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git push', action: 'git'), isFalse);
    });

    test('bare action → allow all commands of that action', () {
      final rule = PermissionRule.fromCommand('bash', 'dart').single;
      expect(rule.kind, RuleKind.action);
      expect(rule.action, 'dart');
      expect(rule.pattern, '');
      expect(rule.matches('bash', 'dart run main.dart', action: 'dart'),
          isTrue);
    });

    test('args with glob chars → wildcard glob', () {
      final rule = PermissionRule.fromCommand('bash', 'rm *.log').single;
      expect(rule.kind, RuleKind.action);
      expect(rule.action, 'rm');
      expect(rule.wildcard, isTrue);
      expect(rule.matches('bash', 'rm error.log', action: 'rm'), isTrue);
      expect(rule.matches('bash', 'rm /var/log/error.log', action: 'rm'),
          isTrue);
    });

    test('compound command → one rule per subcommand, cd skipped', () {
      final rules = PermissionRule.fromCommand(
        'bash',
        r'cd /a && git status && grep -n "foo(\|bar" lib/a.dart | head',
      );
      // cd 忽略;git status 与 grep、head 各一条
      expect(rules, hasLength(3));
      expect(rules[0].action, 'git');
      expect(rules[1].action, 'grep');
      expect(rules[2].action, 'head');
      // 子命令规则可独立命中(无需整串完全相同)
      expect(
        rules[0].matches('bash', 'git status --short', action: 'git'),
        isTrue,
      );
      expect(
        rules[1].matches('bash', r'grep -n "foo(\|bar" lib/a.dart', action: 'grep'),
        isTrue,
      );
      // 含 grep 正则的命令不再让匹配抛 FormatException
      expect(() => rules[1].matches('bash', 'ls', action: 'grep'),
          returnsNormally);
    });

    test('compound with too many subcommands falls back to exact whole', () {
      final rules =
          PermissionRule.fromCommand('bash', 'a; b; c; d; e; f');
      expect(rules, hasLength(1));
      expect(rules.single.kind, RuleKind.exact);
      expect(rules.single.pattern, 'a; b; c; d; e; f');
    });

    test('empty command → allow-all rule for the tool', () {
      final rule = PermissionRule.fromCommand('bash', '').single;
      expect(rule.pattern, '');
      expect(rule.matches('bash', 'anything'), isTrue);
    });
  });

  group('PermissionRule effect (deny)', () {
    test('deny rule roundtrips through json', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'rm',
        pattern: '-rf *',
        wildcard: true,
        effect: RuleEffect.deny,
      );
      final json = rule.toJson();
      expect(json['effect'], 'deny');
      final restored = PermissionRule.fromJson(json)!;
      expect(restored.effect, RuleEffect.deny);
      expect(restored.wildcard, isTrue);
      // 默认 effect 是 allow,json 里不写
      final plain = PermissionRule.fromJson({
        'tool': 'bash',
        'kind': 'action',
        'action': 'git',
      })!;
      expect(plain.effect, RuleEffect.allow);
    });

    test('fromJson rejects unknown effect', () {
      expect(
        PermissionRule.fromJson({
          'tool': 'bash',
          'kind': 'exact',
          'effect': 'maybe',
        }),
        isNull,
      );
    });
  });
}
