import 'dart:io';

import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
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
}
