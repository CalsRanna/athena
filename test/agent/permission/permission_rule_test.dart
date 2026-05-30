import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionRule path matching (file tools)', () {
    test('non-recursive matches direct children only', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/Users/x/Downloads/',
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Downloads/a.txt'),
        isTrue,
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Downloads/sub/c.txt'),
        isFalse,
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Other/a.txt'),
        isFalse,
      );
    });

    test('recursive matches subdirectories', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/Users/x/Downloads/',
        recursive: true,
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Downloads/a.txt'),
        isTrue,
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Downloads/sub/c.txt'),
        isTrue,
      );
      expect(
        rule.matchesAllow('file_read', '/Users/x/Other/a.txt'),
        isFalse,
      );
    });

    test('different tool does not match', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/Users/x/Downloads/',
        recursive: true,
      );
      expect(
        rule.matchesAllow('file_write', '/Users/x/Downloads/a.txt'),
        isFalse,
      );
    });

    test('toJson/fromJson roundtrip preserves recursive', () {
      final rule = PermissionRule(
        tool: 'file_read',
        pattern: '/a/b/',
        recursive: true,
      );
      final json = rule.toJson();
      expect(json['recursive'], isTrue);
      final restored = PermissionRule.fromJson(json);
      expect(restored.recursive, isTrue);
      expect(restored.pattern, '/a/b/');
    });

    test('toJson omits recursive when false', () {
      final rule = PermissionRule(tool: 'file_read', pattern: '/a/b/');
      expect(rule.toJson().containsKey('recursive'), isFalse);
    });
  });

  group('PermissionRule shell command matching', () {
    test('shell pattern matches exact command', () {
      final rule = PermissionRule(tool: 'bash', pattern: 'git status');
      expect(rule.matchesAllow('bash', 'git status'), isTrue);
      expect(rule.matchesAllow('bash', 'git log'), isFalse);
    });
  });

  group('PermissionRule deny normalization', () {
    test('deny matches despite extra whitespace', () {
      final rule = PermissionRule(tool: 'bash', contains: 'rm -rf');
      expect(rule.matchesDeny('bash', 'rm  -rf /x'), isTrue);
    });

    test('deny matches despite case difference', () {
      final rule = PermissionRule(tool: 'bash', contains: 'rm -rf');
      expect(rule.matchesDeny('bash', 'RM -RF /x'), isTrue);
    });
  });

  group('PermissionService generateRule', () {
    final store = PermissionStore();
    final service = PermissionService(store: store);

    test('shell generates exact-command rule, not prefix', () {
      final rule = service.generateRule('bash', {'command': 'git status'});
      expect(rule.tool, 'bash');
      expect(rule.pattern, 'git status');
      expect(rule.recursive, isFalse);
    });

    test('file tool generates directory rule with recursive flag', () {
      final rule = service.generateRule(
        'file_read',
        {'path': '/Users/x/Downloads/a.txt'},
        recursive: true,
      );
      expect(rule.tool, 'file_read');
      expect(rule.pattern, '/Users/x/Downloads/');
      expect(rule.recursive, isTrue);
    });

    test('file tool default is non-recursive', () {
      final rule = service.generateRule(
        'file_write',
        {'path': '/Users/x/Downloads/a.txt'},
      );
      expect(rule.recursive, isFalse);
    });
  });

  group('PermissionService check end-to-end', () {
    test('after persisting non-recursive rule, subdir is not allowed', () async {
      final store = PermissionStore();
      final service = PermissionService(store: store);
      final rule = service.generateRule(
        'file_read',
        {'path': '/Users/x/Downloads/a.txt'},
      );
      // 直接添加到内存（不 save 到磁盘）
      store.allowRules.add(rule);

      expect(
        service.check('file_read', {'path': '/Users/x/Downloads/b.txt'}),
        isTrue,
      );
      expect(
        service.check('file_read', {'path': '/Users/x/Downloads/sub/c.txt'}),
        isNull,
      );
    });

    test('after persisting recursive rule, subdir is allowed', () async {
      final store = PermissionStore();
      final service = PermissionService(store: store);
      final rule = service.generateRule(
        'file_read',
        {'path': '/Users/x/Downloads/a.txt'},
        recursive: true,
      );
      store.allowRules.add(rule);

      expect(
        service.check('file_read', {'path': '/Users/x/Downloads/sub/c.txt'}),
        isTrue,
      );
    });

    test('after persisting exact shell command, different command still asks', () {
      final store = PermissionStore();
      final service = PermissionService(store: store);
      final rule = service.generateRule('bash', {'command': 'git status'});
      store.allowRules.add(rule);

      expect(service.check('bash', {'command': 'git status'}), isTrue);
      expect(service.check('bash', {'command': 'git log'}), isNull);
    });
  });
}
