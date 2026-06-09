import 'dart:io';

import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/permission/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionRule matching', () {
    test('matches file path under allowed directory', () {
      final rule = PermissionRule(tool: 'file_read', pattern: '/Users/x/Downloads/');
      expect(rule.matches('file_read', '/Users/x/Downloads/a.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Downloads/sub/c.txt'), isTrue);
      expect(rule.matches('file_read', '/Users/x/Other/a.txt'), isFalse);
    });

    test('different tool does not match', () {
      final rule = PermissionRule(tool: 'file_read', pattern: '/Users/x/Downloads/');
      expect(rule.matches('file_write', '/Users/x/Downloads/a.txt'), isFalse);
    });

    test('shell pattern matches by prefix', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'git ');
      expect(rule.matches('bash', 'git status'), isTrue);
      expect(rule.matches('bash', 'git log'), isTrue);
      expect(rule.matches('bash', 'ls -la'), isFalse);
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

    test('L0 sandbox block returns false (hard deny) for blacklisted path', () {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/';
      final store = PermissionStore();
      final service = PermissionService(store: store);
      expect(service.check('file_read', {'path': '$home/.ssh/id_rsa'}), isFalse);
    });

    test('sandbox block takes precedence over allow rule', () {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/';
      final service = serviceWithRule(
        PermissionRule(tool: 'file_read', pattern: '$home/.ssh/'),
      );
      // 即使有 allow rule，sandbox 仍然硬拦截
      expect(service.check('file_read', {'path': '$home/.ssh/id_rsa'}), isFalse);
    });

    test('search tool: omitted path defaults to cwd and matches rule', () {
      // PathSandbox.resolveAbsolute canonicalizes; rule must use same output.
      final sandbox = PathSandbox();
      final dir = sandbox.resolveAbsolute('/tmp/athena_search_test');
      final store = PermissionStore()
        ..rules = [PermissionRule(tool: 'search', pattern: '$dir/')];
      final service = PermissionService(store: store, sandbox: sandbox);
      // Explicit path matching the rule
      expect(service.check('search', {'pattern': 'foo', 'path': '/tmp/athena_search_test'}), isTrue);
      // Subdirectory also matches (prefix matching)
      expect(service.check('search', {'pattern': 'foo', 'path': '/tmp/athena_search_test/sub'}), isTrue);
      // Outside the rule does not match
      expect(service.check('search', {'pattern': 'foo', 'path': '/tmp/other'}), isNull);
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
      expect(service.describeRule('file_read'), contains('reads'));
      expect(service.describeRule('file_write'), contains('writes'));
      expect(service.describeRule('file_delete'), contains('deletes'));
      expect(service.describeRule('search'), contains('searching'));
      expect(service.describeRule('list_directory'), contains('listing'));
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

    test('canonicalizes path for file tools', () {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '/';
      final arg = service.primaryArg('file_read', {'path': '$home/Documents/../Downloads/note.md'});
      expect(arg, isNotNull);
      expect(arg, contains('Downloads/note.md'));
    });

    test('extracts origin for web_fetch', () {
      expect(
        service.primaryArg('web_fetch', {'url': 'https://example.com/path?q=1'}),
        'https://example.com',
      );
    });

    test('returns null for non-http URL in web_fetch', () {
      expect(
        service.primaryArg('web_fetch', {'url': 'ftp://x'}),
        isNull,
      );
    });
  });
}
