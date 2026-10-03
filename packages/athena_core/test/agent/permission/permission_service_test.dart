import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:test/test.dart';

void main() {
  late PermissionStore store;
  late PermissionService service;

  setUp(() {
    store = PermissionStore();
    service = PermissionService(store: store);
  });

  test('所有普通调用均交给当前审批模式决定', () {
    for (final call in <String, Map<String, dynamic>>{
      'bash': {'command': 'git status'},
      'powershell': {'command': 'Get-ChildItem'},
      'file_read': {'path': '/workspace/notes.txt'},
      'file_write': {'path': '/workspace/notes.txt', 'content': 'x'},
      'file_update': {
        'path': '/workspace/notes.txt',
        'old_string': 'x',
        'new_string': 'y',
      },
      'web_fetch': {'url': 'https://example.com', 'method': 'POST'},
      'web_search': {'query': 'test'},
      'tool_output_read': {'output_id': 'test'},
      'background_task': {'action': 'list'},
      'experience_recall': {'query': 'test'},
      'sentinel_list': {},
    }.entries) {
      expect(service.check(1, call.key, call.value), PermissionVerdict.prompt);
      expect(
        service.check(1, call.key, call.value),
        PermissionVerdict.prompt,
        reason: '重复调用仍需逐次决定',
      );
    }
  });

  test('shell deny 匹配完整命令，不按子命令匹配且不受目录或后台参数影响', () {
    store.rules.add(
      const PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'rm -rf /',
      ),
    );
    expect(
      service.check(1, 'bash', {
        'command': 'rm -rf /',
        'workdir': '/tmp',
        'background': true,
      }),
      PermissionVerdict.deny,
    );
    expect(
      service.check(1, 'bash', {'command': 'rm -rf / && npm test'}),
      PermissionVerdict.prompt,
    );
  });

  test('文件路径和网址禁令继续生效', () {
    store.rules.addAll([
      const PermissionRule(
        tool: 'file_write',
        kind: RuleKind.path,
        pattern: '/workspace/*.txt',
      ),
      const PermissionRule(
        tool: 'web_fetch',
        kind: RuleKind.origin,
        pattern: 'https://example.com',
      ),
    ]);
    expect(
      service.check(1, 'file_write', {'path': '/workspace/notes.txt'}),
      PermissionVerdict.deny,
    );
    expect(
      service.check(1, 'file_write', {'path': '/workspace/sub/notes.txt'}),
      PermissionVerdict.prompt,
    );
    for (final method in ['GET', 'POST']) {
      expect(
        service.check(1, 'web_fetch', {
          'url': 'https://example.com/docs',
          'method': method,
        }),
        PermissionVerdict.deny,
      );
    }
  });

  test('用户拒绝按 run 和完整执行参数隔离，并忽略展示描述与键顺序', () {
    service.denyForSession(1, 'bash', {
      'command': 'git status',
      'workdir': '/workspace/a',
      'call_description': '查看',
    });
    expect(
      service.check(1, 'bash', {
        'workdir': '/workspace/a',
        'command': 'git status',
        'call_description': '重试',
      }),
      PermissionVerdict.deny,
    );
    expect(
      service.check(2, 'bash', {
        'command': 'git status',
        'workdir': '/workspace/a',
      }),
      PermissionVerdict.prompt,
    );
    expect(
      service.check(1, 'bash', {
        'command': 'git status',
        'workdir': '/workspace/b',
      }),
      PermissionVerdict.prompt,
    );
    service.resetSession(1);
    expect(
      service.check(1, 'bash', {
        'command': 'git status',
        'workdir': '/workspace/a',
      }),
      PermissionVerdict.prompt,
    );
  });
}
