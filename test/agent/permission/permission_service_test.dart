import 'dart:io';

import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/permission/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionService path canonicalization (S2)', () {
    PermissionService serviceWithAllow(PermissionRule rule) {
      final store = PermissionStore()..allowRules = [rule];
      return PermissionService(store: store);
    }

    test('recursive allow does NOT auto-approve a `..` traversal escape', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'file_write', pattern: '/a/b/', recursive: true),
      );
      // Canonical path resolves to /etc/x which is outside /a/b/.
      expect(
        service.check('file_write', {'path': '/a/b/../../etc/x'}),
        isNull,
      );
    });

    test('recursive allow auto-approves a legitimate nested path', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'file_write', pattern: '/a/b/', recursive: true),
      );
      expect(
        service.check('file_write', {'path': '/a/b/sub/file'}),
        isTrue,
      );
    });

    test('duplicate slashes canonicalize and still match', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'file_write', pattern: '/a/b/', recursive: true),
      );
      expect(
        service.check('file_write', {'path': '/a/b//sub/file'}),
        isTrue,
      );
    });

    test('trailing-slash differences canonicalize and still match', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'file_read', pattern: '/a/b/', recursive: true),
      );
      // Non-recursive direct child after canonicalization.
      final nonRecursive = serviceWithAllow(
        PermissionRule(tool: 'file_read', pattern: '/a/b/'),
      );
      expect(service.check('file_read', {'path': '/a/b/c/'}), isTrue);
      expect(nonRecursive.check('file_read', {'path': '/a/b/c/'}), isTrue);
    });

    test('relative path with `..` resolves against cwd and does not match '
        'an unrelated allow rule', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'file_write', pattern: '/a/b/', recursive: true),
      );
      // Resolves against Directory.current, never under /a/b/.
      expect(
        service.check('file_write', {'path': '../../some/file'}),
        isNull,
      );
    });
  });

  group('PermissionService search/list_directory gating (S1)', () {
    test('search allow rule matches a request inside the directory', () {
      final dir = Directory.current.path;
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(tool: 'search', pattern: '$dir/', recursive: true),
        ];
      final service = PermissionService(store: store);
      expect(
        service.check('search', {'pattern': 'foo', 'path': '$dir/lib'}),
        isTrue,
      );
    });

    test('search request outside the allowed directory is not auto-approved',
        () {
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(tool: 'search', pattern: '/a/b/', recursive: true),
        ];
      final service = PermissionService(store: store);
      expect(
        service.check('search', {'pattern': 'foo', 'path': '/c/d'}),
        isNull,
      );
    });

    test('list_directory allow rule matches a request inside the directory',
        () {
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(
            tool: 'list_directory',
            pattern: '/a/b/',
            recursive: true,
          ),
        ];
      final service = PermissionService(store: store);
      expect(
        service.check('list_directory', {'path': '/a/b/sub'}),
        isTrue,
      );
      expect(
        service.check('list_directory', {'path': '/c/d'}),
        isNull,
      );
    });

    test('search with omitted path defaults to cwd and matches a rule on cwd '
        'itself', () {
      final dir = Directory.current.path;
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(tool: 'search', pattern: '$dir/', recursive: true),
        ];
      final service = PermissionService(store: store);
      expect(service.check('search', {'pattern': 'foo'}), isTrue);
    });

    test('recursive search rule matches the directory itself and descendants',
        () {
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(tool: 'search', pattern: '/a/b/c/', recursive: true),
        ];
      final service = PermissionService(store: store);
      expect(service.check('search', {'pattern': 'x', 'path': '/a/b/c'}),
          isTrue);
      expect(service.check('search', {'pattern': 'x', 'path': '/a/b/c/sub'}),
          isTrue);
    });

    test('non-recursive search rule matches dir itself and direct children '
        'only', () {
      final store = PermissionStore()
        ..allowRules = [
          PermissionRule(tool: 'search', pattern: '/a/b/c/'),
        ];
      final service = PermissionService(store: store);
      expect(service.check('search', {'pattern': 'x', 'path': '/a/b/c'}),
          isTrue);
      expect(service.check('search', {'pattern': 'x', 'path': '/a/b/c/foo'}),
          isTrue);
      expect(
        service.check('search', {'pattern': 'x', 'path': '/a/b/c/sub/deep'}),
        isNull,
      );
    });
  });

  group('PermissionService rule generation (S1)', () {
    test('generateRule for search scopes to the searched directory itself', () {
      final service = PermissionService(store: PermissionStore());
      final rule = service.generateRule(
        'search',
        {'pattern': 'foo', 'path': '/a/b/c'},
        recursive: true,
      );
      expect(rule.tool, 'search');
      expect(rule.recursive, isTrue);
      expect(rule.pattern, '/a/b/c/');
    });

    test('generateRuleDescription for search/list_directory', () {
      final service = PermissionService(store: PermissionStore());
      expect(
        service.generateRuleDescription('search', {'path': '/a/b/c'}),
        contains('searching'),
      );
      expect(
        service.generateRuleDescription('list_directory', {'path': '/a/b/c'}),
        contains('listing'),
      );
    });
  });

  group('PermissionService web_fetch origin scoping (S4)', () {
    PermissionService serviceWithAllow(PermissionRule rule) {
      final store = PermissionStore()..allowRules = [rule];
      return PermissionService(store: store);
    }

    test('origin allow rule auto-approves another path on the same origin', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'https://a.com/some/path'}),
        isTrue,
      );
    });

    test('origin allow rule does NOT auto-approve a different host', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'https://b.com/'}),
        isNull,
      );
    });

    test('a different scheme is a different origin', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'http://a.com/'}),
        isNull,
      );
    });

    test('a different port is a different origin', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'https://a.com:8443/'}),
        isNull,
      );
    });

    test('userinfo in the URL does not widen the rule', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'https://user:pass@a.com/x'}),
        isTrue,
      );
    });

    test('uppercase host is normalized to the same origin', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'https://A.COM/x'}),
        isTrue,
      );
    });

    test('generateRule produces a non-null origin-scoped pattern', () {
      final service = PermissionService(store: PermissionStore());
      final rule = service.generateRule(
        'web_fetch',
        {'url': 'https://a.com/x?y=1'},
      );
      expect(rule.tool, 'web_fetch');
      expect(rule.pattern, isNotNull);
      expect(rule.pattern, 'https://a.com');
    });

    test('generateRuleDescription contains the origin', () {
      final service = PermissionService(store: PermissionStore());
      expect(
        service.generateRuleDescription('web_fetch', {'url': 'https://a.com/x'}),
        contains('https://a.com'),
      );
    });

    test('a malformed/non-http URL is never auto-approved', () {
      final service = serviceWithAllow(
        PermissionRule(tool: 'web_fetch', pattern: 'https://a.com'),
      );
      expect(
        service.check('web_fetch', {'url': 'ftp://x'}),
        isNull,
      );
      expect(
        service.check('web_fetch', {'url': 'not a url'}),
        isNull,
      );
    });

    test('generateRule never yields a null pattern for a non-http url', () {
      final service = PermissionService(store: PermissionStore());
      final rule = service.generateRule('web_fetch', {'url': 'ftp://x'});
      expect(rule.tool, 'web_fetch');
      expect(rule.pattern, isNotNull);
    });
  });

  group('PermissionService web_fetch SSRF danger (S4)', () {
    final service = PermissionService(store: PermissionStore());

    test('link-local / cloud-metadata is dangerous (hide checkbox)', () {
      expect(
        service.isDangerous('web_fetch', {'url': 'http://169.254.169.254/'}),
        isTrue,
      );
    });

    test('loopback is dangerous', () {
      expect(
        service.isDangerous('web_fetch', {'url': 'http://127.0.0.1/'}),
        isTrue,
      );
      expect(
        service.isDangerous('web_fetch', {'url': 'http://localhost:3000/'}),
        isTrue,
      );
    });

    test('private LAN is dangerous', () {
      expect(
        service.isDangerous('web_fetch', {'url': 'http://192.168.1.1/'}),
        isTrue,
      );
    });

    test('public host is not dangerous', () {
      expect(
        service.isDangerous('web_fetch', {'url': 'https://example.com/'}),
        isFalse,
      );
    });
  });

  group('PermissionService isDangerous pipe-to-interpreter (S8)', () {    final service = PermissionService(store: PermissionStore());

    test('pipe to python/node/perl/ruby is dangerous (hide checkbox)', () {
      expect(
        service.isDangerous('bash', {'command': 'curl x | python'}),
        isTrue,
      );
      expect(
        service.isDangerous('bash', {'command': 'curl x | node'}),
        isTrue,
      );
      expect(
        service.isDangerous('bash', {'command': 'curl x | perl'}),
        isTrue,
      );
      expect(
        service.isDangerous('bash', {'command': 'curl x | ruby'}),
        isTrue,
      );
    });

    test('pipe to interpreter is case-insensitive (PYTHON)', () {
      expect(
        service.isDangerous('bash', {'command': 'curl x | PYTHON'}),
        isTrue,
      );
    });

    test('benign command is not dangerous', () {
      expect(
        service.isDangerous('bash', {'command': 'git status'}),
        isFalse,
      );
    });

    test('pipe-to-interpreter is NOT hard-denied by the sandbox', () {
      // It must remain runnable with a per-use approval.
      expect(PathSandbox().canExecute('curl x | python'), isTrue);
    });
  });
}
