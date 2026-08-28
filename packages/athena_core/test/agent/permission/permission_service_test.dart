import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:test/test.dart';

/// 模拟一条坏规则(匹配时抛异常),验证单条坏规则不会炸掉所有调用。
class _ThrowingRule extends PermissionRule {
  _ThrowingRule() : super(tool: 'bash', kind: RuleKind.exact);

  @override
  bool matches(String toolName, String? keyArg, {String? action}) {
    throw const FormatException('Unterminated group');
  }
}

void main() {
  group('PermissionRule matching', () {
    test('path rule matches under allowed directory', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/Users/x/Downloads/',
      );
      expect(rule.matches('file_read', '/Users/x/Downloads/a.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Downloads/sub/c.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Other/a.txt'), isFalse);
    });

    test('different tool does not match', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/Users/x/Downloads/',
      );
      expect(rule.matches('file_write', '/Users/x/Downloads/a.txt'), isFalse);
    });

    test('action rule matches by action', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'git',
      );
      expect(rule.matches('bash', 'git status', action: 'git'), isTrue);
      expect(rule.matches('bash', 'git log', action: 'git'), isTrue);
      expect(rule.matches('bash', 'ls -la', action: 'ls'), isFalse);
    });

    test('action glob matches wildcards, * crosses /', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'rm',
        pattern: '*.log',
        wildcard: true,
      );
      expect(rule.matches('bash', 'rm error.log', action: 'rm'), isTrue);
      expect(rule.matches('bash', 'rm access.log', action: 'rm'), isTrue);
      expect(rule.matches('bash', 'rm /var/log/error.log', action: 'rm'),
          isTrue);
    });

    test('action glob with ? matches single char', () {
      final rule = PermissionRule(
        tool: 'bash',
        kind: RuleKind.action,
        action: 'ls',
        pattern: 'file?.txt',
        wildcard: true,
      );
      expect(rule.matches('bash', 'ls file1.txt', action: 'ls'), isTrue);
      expect(rule.matches('bash', 'ls fileA.txt', action: 'ls'), isTrue);
      expect(rule.matches('bash', 'ls file12.txt', action: 'ls'), isFalse);
    });

    test('empty pattern matches everything for that tool', () {
      final rule = PermissionRule(tool: 'web_search', kind: RuleKind.exact);
      expect(rule.matches('web_search', null), isTrue);
      expect(rule.matches('web_search', 'anything'), isTrue);
      expect(rule.matches('other_tool', 'anything'), isFalse);
    });

    test('toJson/fromJson roundtrip', () {
      final rule = PermissionRule(
        tool: 'file_read',
        kind: RuleKind.path,
        pattern: '/a/b/',
      );
      final json = rule.toJson();
      expect(json['tool'], 'file_read');
      expect(json['kind'], 'path');
      expect(json['pattern'], '/a/b/');
      final restored = PermissionRule.fromJson(json)!;
      expect(restored.tool, 'file_read');
      expect(restored.pattern, '/a/b/');
      expect(restored.kind, RuleKind.path);
    });
  });

  group('PermissionService check', () {
    PermissionService serviceWithRules(List<PermissionRule> rules) {
      final store = PermissionStore()..rules = rules;
      return PermissionService(store: store);
    }

    test('cached rule auto-approves matching request', () {
      final service = serviceWithRules([
        PermissionRule(
          tool: 'file_read',
          kind: RuleKind.path,
          pattern: '/a/b/',
        ),
      ]);
      expect(
        service.check(1, 'file_read', {'path': '/a/b/c.txt'}),
        PermissionVerdict.allow,
      );
    });

    test('no rule returns prompt (needs approval)', () {
      final service = serviceWithRules([]);
      expect(
        service.check(1, 'file_read', {'path': '/a/b/c.txt'}),
        PermissionVerdict.prompt,
      );
    });

    test('all paths allowed without sandbox', () {
      final service = serviceWithRules([]);
      // No sandbox: even sensitive paths need user approval, not auto-denied
      expect(
        service.check(1, 'file_read', {'path': '/etc/passwd'}),
        PermissionVerdict.prompt,
      );
    });

    test('web_fetch origin matching', () {
      final service = serviceWithRules([
        PermissionRule(
          tool: 'web_fetch',
          kind: RuleKind.origin,
          pattern: 'https://a.com',
        ),
      ]);
      expect(
        service.check(1, 'web_fetch', {'url': 'https://a.com/path'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'web_fetch', {'url': 'https://b.com/path'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'web_fetch', {'url': 'http://a.com/path'}),
        PermissionVerdict.prompt,
      );
    });

    test('shell action rule matches', () {
      final service = serviceWithRules([
        PermissionRule(tool: 'bash', kind: RuleKind.action, action: 'git'),
      ]);
      // git log 是只读命令,直接短路放行
      expect(
        service.check(1, 'bash', {'command': 'git log -1'}),
        PermissionVerdict.allow,
      );
      // 命中动作级规则(无副作用子命令)直接放行
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.allow,
      );
      // 其他动作(无规则)需要审批
      expect(
        service.check(1, 'bash', {'command': 'npm install'}),
        PermissionVerdict.prompt,
      );
    });

    test('broken rule is skipped, not fatal', () {
      // 回归:曾经一条坏规则让所有 bash 调用抛 FormatException
      final service = serviceWithRules([_ThrowingRule()]);
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'bash', {'command': 'rm file.txt'}),
        PermissionVerdict.prompt,
      );
    });

    test('readOnly tool bypasses rules entirely', () {
      final service = serviceWithRules([]);
      expect(
        service.check(1, 'web_fetch',
          {'url': 'https://a.com/path'},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.allow,
      );
    });

    test('web_fetch POST / custom headers require approval', () {
      final service = serviceWithRules([]);
      // GET 无自定义 headers：readOnly 短路放行
      expect(
        service.check(1, 'web_fetch',
          {'url': 'https://a.com/path'},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.allow,
      );
      // POST：即使工具声明 readOnly 也需弹窗
      expect(
        service.check(1, 'web_fetch',
          {'url': 'https://a.com/path', 'method': 'POST', 'body': 'x=1'},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.prompt,
      );
      // 自定义 headers：需弹窗
      expect(
        service.check(1, 'web_fetch',
          {'url': 'https://a.com/path', 'headers': {'X-Token': 'abc'}},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.prompt,
      );
      // 显式 GET 仍放行
      expect(
        service.check(1, 'web_fetch',
          {'url': 'https://a.com/path', 'method': 'GET'},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.allow,
      );
      // 非 web_fetch 工具不受影响
      expect(
        service.check(1, 'web_search',
          {'q': 'x'},
          risk: ToolRisk.readOnly,
        ),
        PermissionVerdict.allow,
      );
    });

    test('readOnly shell command bypasses rules', () {
      final service = serviceWithRules([]);
      expect(
        service.check(1, 'bash', {'command': 'ls -la'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'bash', {'command': 'cd /a && ls -la'}),
        PermissionVerdict.allow,
      );
      // 有副作用命令仍需审批
      expect(
        service.check(1, 'bash', {'command': 'rm file.txt'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.prompt,
      );
    });

    test('action-level rule matches by action', () {
      final service = serviceWithRules([
        PermissionRule(tool: 'bash', kind: RuleKind.action, action: 'git'),
      ]);
      expect(
        service.check(1, 'bash', {'command': 'git status'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'bash', {'command': 'git push origin main'}),
        PermissionVerdict.allow,
      );
      // 其他动作不匹配
      expect(
        service.check(1, 'bash', {'command': 'npm install'}),
        PermissionVerdict.prompt,
      );
    });

    test('action rule with pattern narrows arguments', () {
      final service = serviceWithRules([
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.action,
          action: 'git',
          pattern: 'status',
        ),
      ]);
      expect(
        service.check(1, 'bash', {'command': 'git status -s'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'bash', {'command': 'git status --short'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.prompt,
      );
    });

    test('compound command: each subcommand must be covered', () {
      // 与「复合命令按子命令分别建模」的落库方式对应
      final service = serviceWithRules([
        ...PermissionRule.fromCommand('bash', 'git status'),
        ...PermissionRule.fromCommand('bash', 'npm test'),
      ]);
      // 子命令各自命中(或只读)→ 整条放行
      expect(
        service.check(1, 'bash', {'command': 'cd /a && git status && npm test'}),
        PermissionVerdict.allow,
      );
      // cd 子命令只读、git status 只读,不构成弹窗
      expect(
        service.check(1, 'bash', {'command': 'cd /a && git status && git diff'}),
        PermissionVerdict.allow,
      );
      // npm install 未被覆盖 → 弹窗
      expect(
        service.check(1, 'bash', {'command': 'git status && npm install'}),
        PermissionVerdict.prompt,
      );
      // 整条 exact 规则(exact 回退的复合命令)仍可放行
      final exactService = serviceWithRules([
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.exact,
          pattern: 'a; b; c; d; e; f',
        ),
      ]);
      expect(
        exactService.check(1, 'bash', {'command': 'a; b; c; d; e; f'}),
        PermissionVerdict.allow,
      );
    });

    test('deny rule overrides readOnly and allow rules', () {
      final service = serviceWithRules([
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.action,
          action: 'rm',
          pattern: '*.log',
          wildcard: true,
        ),
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.action,
          action: 'rm',
          pattern: '-rf *',
          wildcard: true,
          effect: RuleEffect.deny,
        ),
      ]);
      // allow 规则命中 → 放行
      expect(
        service.check(1, 'bash', {'command': 'rm error.log'}),
        PermissionVerdict.allow,
      );
      // deny 规则命中 → 直接拒绝(即使同时匹配 allow)
      expect(
        service.check(1, 'bash', {'command': 'rm -rf /tmp/x'}),
        PermissionVerdict.deny,
      );
      // deny 优先于只读短路
      final denyCat = serviceWithRules([
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.action,
          action: 'cat',
          effect: RuleEffect.deny,
        ),
      ]);
      expect(
        denyCat.check(1, 'bash', {'command': 'cat README.md'}),
        PermissionVerdict.deny,
      );
    });

    test('deny scans compound subcommands', () {
      final service = serviceWithRules([
        PermissionRule(
          tool: 'bash',
          kind: RuleKind.action,
          action: 'rm',
          pattern: '-rf *',
          wildcard: true,
          effect: RuleEffect.deny,
        ),
      ]);
      // 子命令命中 deny → 整条拒绝
      expect(
        service.check(1, 'bash', {'command': 'ls && rm -rf /tmp/x'}),
        PermissionVerdict.deny,
      );
      expect(
        service.check(1, 'bash', {'command': 'ls -la'}),
        PermissionVerdict.allow,
      );
    });

    test('session approval bypasses rules within same run', () async {
      final service = serviceWithRules([]);
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.prompt,
      );

      await service.approveForSession(1, 'bash', {'command': 'git push'});
      // 同动作同子命令放行（含参数变体）
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.allow,
      );
      expect(
        service.check(1, 'bash', {'command': 'git push origin main'}),
        PermissionVerdict.allow,
      );
      // 其他动作不放行
      expect(
        service.check(1, 'bash', {'command': 'npm install'}),
        PermissionVerdict.prompt,
      );
    });

    test('session approval is subcommand-granular (not whole action)', () async {
      final service = serviceWithRules([]);

      await service.approveForSession(1, 'bash', {'command': 'git push'});
      // 同子命令放行
      expect(
        service.check(1, 'bash', {'command': 'git push --force origin main'}),
        PermissionVerdict.allow,
      );
      // 不同子命令仍需弹窗——批准 git push 不得放行 git reset --hard
      expect(
        service.check(1, 'bash', {'command': 'git reset --hard'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'bash', {'command': 'git clean -fdx'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'bash', {'command': 'git push2'}),
        PermissionVerdict.prompt,
      );
    });

    test('bash and powershell do not share session approval', () async {
      final service = serviceWithRules([]);

      await service.approveForSession(1, 'bash', {'command': 'rm file.txt'});
      // powershell 的 rm 需要单独审批
      expect(
        service.check(1, 'powershell', {'command': 'rm file.txt'}),
        PermissionVerdict.prompt,
      );
      expect(
        service.check(1, 'bash', {'command': 'rm file.txt'}),
        PermissionVerdict.allow,
      );
    });

    test('resetSession clears session approvals', () async {
      final service = serviceWithRules([]);
      await service.approveForSession(1, 'bash', {'command': 'git push'});
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.allow,
      );

      service.resetSession(1);
      expect(
        service.check(1, 'bash', {'command': 'git push'}),
        PermissionVerdict.prompt,
      );
    });
  });

  group('PermissionService primaryArg', () {
    final store = PermissionStore();
    final service = PermissionService(store: store);

    test('extracts command for shell tools', () {
      expect(
        service.primaryArg('bash', {'command': 'git status'}),
        'git status',
      );
    });

    test('extracts path for file tools', () {
      expect(
        service.primaryArg('file_read', {'path': '/a/b/c.txt'}),
        '/a/b/c.txt',
      );
    });

    test('extracts origin for web_fetch', () {
      expect(
        service.primaryArg('web_fetch', {
          'url': 'https://example.com/path?q=1',
        }),
        'https://example.com',
      );
    });

    test('returns null for non-http URL in web_fetch', () {
      expect(service.primaryArg('web_fetch', {'url': 'ftp://x'}), isNull);
    });
  });
}
