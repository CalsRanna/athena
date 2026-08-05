import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionRule matching', () {
    test('matches file path under allowed directory', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/Users/x/Downloads/',
      );
      expect(rule.matches('file_read', '/Users/x/Downloads/a.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Downloads/sub/c.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Other/a.txt'), isFalse);
    });

    test('different tool does not match', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/Users/x/Downloads/',
      );
      expect(rule.matches('file_write', '/Users/x/Downloads/a.txt'), isFalse);
    });

    test('shell pattern matches by prefix', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'git ');
      expect(rule.matches('bash', 'git status'), isTrue);
      expect(rule.matches('bash', 'git log'), isTrue);
      expect(rule.matches('bash', 'ls -la'), isFalse);
    });

    test('glob pattern matches wildcards', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'rm *.log');
      expect(rule.matches('bash', 'rm error.log'), isTrue);
      expect(rule.matches('bash', 'rm access.log'), isTrue);
      expect(rule.matches('bash', 'rm /var/log/error.log'), isFalse);
    });

    test('glob pattern with ? matches single char', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'ls file?.txt');
      expect(rule.matches('bash', 'ls file1.txt'), isTrue);
      expect(rule.matches('bash', 'ls fileA.txt'), isTrue);
      expect(rule.matches('bash', 'ls file12.txt'), isFalse);
    });

    test('empty pattern matches everything for that tool', () {
      final rule = PermissionRule(tool: 'web_search');
      expect(rule.matches('web_search', null), isTrue);
      expect(rule.matches('web_search', 'anything'), isTrue);
      expect(rule.matches('other_tool', 'anything'), isFalse);
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
  });

  group('PermissionService check', () {
    PermissionService serviceWithRule(PermissionRule rule) {
      final store = PermissionStore()..rules = [rule];
      return PermissionService(store: store);
    }

    test('cached rule auto-approves matching request', () {
      final service = serviceWithRule(
        PermissionRule(tool: 'file_read', pattern: '/a/b/'),
      );
      expect(service.check('file_read', {'path': '/a/b/c.txt'}), isTrue);
    });

    test('no rule returns null (needs approval)', () {
      final store = PermissionStore();
      final service = PermissionService(store: store);
      expect(service.check('file_read', {'path': '/a/b/c.txt'}), isNull);
    });

    test('all paths allowed without sandbox', () {
      final store = PermissionStore();
      final service = PermissionService(store: store);
      // No sandbox: even sensitive paths need user approval, not auto-denied
      expect(service.check('file_read', {'path': '/etc/passwd'}), isNull);
    });

    test('web_fetch origin matching', () {
      final service = serviceWithRule(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(service.check('web_fetch', {'url': 'https://a.com/path'}), isTrue);
      expect(service.check('web_fetch', {'url': 'https://b.com/path'}), isNull);
      expect(service.check('web_fetch', {'url': 'http://a.com/path'}), isNull);
    });

    test('shell command prefix matching', () {
      final service = serviceWithRule(
        PermissionRule(tool: 'bash', pattern: 'git '),
      );
      // git status 是只读命令,直接短路放行
      expect(service.check('bash', {'command': 'git status'}), isTrue);
      // 有副作用命令(无规则)需要审批
      expect(service.check('bash', {'command': 'npm install'}), isNull);
    });

    test('readOnly tool bypasses rules entirely', () {
      final service = PermissionService(store: PermissionStore());
      expect(
        service.check(
          'web_fetch',
          {'url': 'https://a.com/path'},
          risk: ToolRisk.readOnly,
        ),
        isTrue,
      );
    });

    test('web_fetch POST / custom headers require approval', () {
      final service = PermissionService(store: PermissionStore());
      // GET 无自定义 headers：readOnly 短路放行
      expect(
        service.check(
          'web_fetch',
          {'url': 'https://a.com/path'},
          risk: ToolRisk.readOnly,
        ),
        isTrue,
      );
      // POST：即使工具声明 readOnly 也需弹窗
      expect(
        service.check(
          'web_fetch',
          {'url': 'https://a.com/path', 'method': 'POST', 'body': 'x=1'},
          risk: ToolRisk.readOnly,
        ),
        isNull,
      );
      // 自定义 headers：需弹窗
      expect(
        service.check(
          'web_fetch',
          {'url': 'https://a.com/path', 'headers': {'X-Token': 'abc'}},
          risk: ToolRisk.readOnly,
        ),
        isNull,
      );
      // 显式 GET 仍放行
      expect(
        service.check(
          'web_fetch',
          {'url': 'https://a.com/path', 'method': 'GET'},
          risk: ToolRisk.readOnly,
        ),
        isTrue,
      );
      // 非 web_fetch 工具不受影响
      expect(
        service.check(
          'web_search',
          {'q': 'x'},
          risk: ToolRisk.readOnly,
        ),
        isTrue,
      );
    });

    test('readOnly shell command bypasses rules', () {
      final service = PermissionService(store: PermissionStore());
      expect(service.check('bash', {'command': 'ls -la'}), isTrue);
      expect(service.check('bash', {'command': 'cat README.md'}), isTrue);
      // 有副作用命令仍需审批
      expect(service.check('bash', {'command': 'rm file.txt'}), isNull);
      expect(service.check('bash', {'command': 'git push'}), isNull);
    });

    test('action-level rule matches by action', () {
      final service = serviceWithRule(
        PermissionRule(tool: 'bash', action: 'git'),
      );
      expect(service.check('bash', {'command': 'git status'}), isTrue);
      expect(service.check('bash', {'command': 'git push origin main'}), isTrue);
      // 其他动作不匹配
      expect(service.check('bash', {'command': 'npm install'}), isNull);
    });

    test('session approval bypasses rules within same run', () async {
      final service = PermissionService(store: PermissionStore());
      expect(service.check('bash', {'command': 'git push'}), isNull);

      await service.approveForSession('bash', {'command': 'git push'});
      // 同动作同子命令放行（含参数变体）
      expect(service.check('bash', {'command': 'git push'}), isTrue);
      expect(
        service.check('bash', {'command': 'git push origin main'}),
        isTrue,
      );
      // 其他动作不放行
      expect(service.check('bash', {'command': 'npm install'}), isNull);
    });

    test('session approval is subcommand-granular (not whole action)', () async {
      final service = PermissionService(store: PermissionStore());

      await service.approveForSession('bash', {'command': 'git push'});
      // 同子命令放行
      expect(service.check('bash', {'command': 'git push --force origin main'}),
          isTrue);
      // 不同子命令仍需弹窗——批准 git push 不得放行 git reset --hard
      expect(service.check('bash', {'command': 'git reset --hard'}), isNull);
      expect(service.check('bash', {'command': 'git clean -fdx'}), isNull);
      expect(service.check('bash', {'command': 'git push2'}), isNull);
    });

    test('bash and powershell do not share session approval', () async {
      final service = PermissionService(store: PermissionStore());

      await service.approveForSession('bash', {'command': 'rm file.txt'});
      // powershell 的 rm 需要单独审批
      expect(service.check('powershell', {'command': 'rm file.txt'}), isNull);
      expect(service.check('bash', {'command': 'rm file.txt'}), isTrue);
    });

    test('resetSession clears session approvals', () async {
      final service = PermissionService(store: PermissionStore());
      await service.approveForSession('bash', {'command': 'git push'});
      expect(service.check('bash', {'command': 'git push'}), isTrue);

      service.resetSession();
      expect(service.check('bash', {'command': 'git push'}), isNull);
    });
  });

  group('PermissionService describeRule', () {
    final store = PermissionStore();
    final service = PermissionService(store: store);

    test('describes each tool type', () {
      expect(service.describeRule('bash'), contains('command'));
      expect(service.describeRule('powershell'), contains('command'));
      expect(service.describeRule('file_read'), contains('reads'));
      expect(service.describeRule('file_write'), contains('writes'));
      expect(service.describeRule('file_update'), contains('writes'));
      expect(service.describeRule('web_fetch'), contains('domain'));
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
