import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(service.check('bash', {'command': 'git status'}), isTrue);
      expect(service.check('bash', {'command': 'ls -la'}), isNull);
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
