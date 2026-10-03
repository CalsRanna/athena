import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:test/test.dart';

void main() {
  test('旧 allow 和省略 effect 的放行规则停止生效，不转换成 deny', () {
    for (final kind in RuleKind.values) {
      for (final effect in [null, 'allow', 'unknown']) {
        expect(
          PermissionRule.fromJson({
            'tool': switch (kind) {
              RuleKind.exact => 'bash',
              RuleKind.path => 'file_write',
              RuleKind.origin => 'web_fetch',
            },
            'kind': kind.name,
            'pattern': '',
            if (effect != null) 'effect': effect,
          }),
          isNull,
        );
      }
    }
  });

  test('exact、path、origin 禁令往返序列化后仍生效', () {
    for (final rule in [
      const PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'rm -rf build',
      ),
      const PermissionRule(
        tool: 'file_write',
        kind: RuleKind.path,
        pattern: '/tmp/*.txt',
      ),
      const PermissionRule(
        tool: 'web_fetch',
        kind: RuleKind.origin,
        pattern: 'https://a.com',
      ),
    ]) {
      final decoded = PermissionRule.fromJson(rule.toJson());
      expect(decoded?.toJson(), rule.toJson());
      expect(decoded?.matches(rule.tool, rule.pattern), isTrue);
      expect(rule.toJson()['effect'], 'deny');
    }
  });

  test('旧 action 和非法工具类型规则不生效', () {
    for (final json in [
      {'tool': 'bash', 'kind': 'action', 'effect': 'deny'},
      {'tool': 'bash', 'kind': 'path', 'effect': 'deny'},
      {'tool': 'file_write', 'kind': 'origin', 'effect': 'deny'},
      {'tool': 'bash', 'kind': 'exact', 'effect': 'deny', 'wildcard': true},
    ]) {
      expect(PermissionRule.fromJson(json), isNull);
    }
  });

  group('shell 禁令的文本匹配边界', () {
    const rule = PermissionRule(
      tool: 'bash',
      kind: RuleKind.exact,
      pattern: 'rm -rf ~',
    );
    test('折叠空白并去掉参数末尾斜杠', () {
      expect(rule.matches('bash', 'rm   -rf\t~/'), isTrue);
      expect(rule.matches('bash', '  rm -rf ~  '), isTrue);
    });
    test('不扩展到新增参数、子路径或其他工具', () {
      expect(rule.matches('bash', 'rm -rf ~/data'), isFalse);
      expect(rule.matches('bash', 'rm -rf ~ -f'), isFalse);
      expect(rule.matches('powershell', 'rm -rf ~'), isFalse);
    });
    test('保留根目录斜杠', () {
      const root = PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'rm -rf /',
      );
      expect(root.matches('bash', 'rm -rf'), isFalse);
    });
    test('不做命令语义分析', () {
      expect(rule.matches('bash', 'rm -fr ~'), isFalse);
      expect(rule.matches('bash', '/bin/rm -rf ~'), isFalse);
      expect(rule.matches('bash', 'bash -c "rm -rf ~"'), isFalse);
    });
    test('非 shell exact 不折叠空白与斜杠', () {
      const other = PermissionRule(
        tool: 'web_search',
        kind: RuleKind.exact,
        pattern: 'a/',
      );
      expect(other.matches('web_search', 'a'), isFalse);
    });
  });

  test('path glob 和目录前缀保留路径边界，origin 保留主机边界', () {
    const path = PermissionRule(
      tool: 'file_write',
      kind: RuleKind.path,
      pattern: '/w',
    );
    const glob = PermissionRule(
      tool: 'file_write',
      kind: RuleKind.path,
      pattern: '/w/*.txt',
    );
    const origin = PermissionRule(
      tool: 'web_fetch',
      kind: RuleKind.origin,
      pattern: 'https://a.com',
    );
    expect(path.matches('file_write', '/w/sub/a.txt'), isTrue);
    expect(path.matches('file_write', '/wrong/a.txt'), isFalse);
    expect(glob.matches('file_write', '/w/a.txt'), isTrue);
    expect(glob.matches('file_write', '/w/sub/a.txt'), isFalse);
    expect(origin.matches('web_fetch', 'https://a.com/x'), isTrue);
    expect(origin.matches('web_fetch', 'https://a.com.evil.com'), isFalse);
  });
}
