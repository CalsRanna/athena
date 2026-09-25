import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/powershell_shell_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:test/test.dart';

void main() {
  late PermissionStore store;
  late PermissionService service;

  setUp(() {
    // 只使用内存规则,不读写用户的 permissions.json。
    store = PermissionStore();
    service = PermissionService(store: store);
  });

  PermissionVerdict check(String command, {String tool = 'bash'}) =>
      service.check(1, tool, {'command': command});

  test('shell 不再按命令文本免审批', () {
    for (final tool in kShellToolNames) {
      for (final command in [
        'ls -la',
        'git status',
        'ls | head -100',
        'cd /tmp && git status',
        'sort -o out.txt input.txt',
        "sed 'w out.txt' input.txt",
        'dart test',
        'Get-ChildItem',
      ]) {
        expect(
          check(command, tool: tool),
          PermissionVerdict.prompt,
          reason: '$tool: $command',
        );
      }
    }
  });

  test('单条命令的授权不能拼接为复合命令授权', () {
    store.rules.addAll([
      ...PermissionRule.forToolCall('bash', 'git status'),
      ...PermissionRule.forToolCall('bash', 'npm test'),
    ]);

    expect(check('git status'), PermissionVerdict.allow);
    expect(check('git status -s'), PermissionVerdict.prompt);
    expect(check('git status && npm test'), PermissionVerdict.prompt);
    store.rules.addAll(
      PermissionRule.forToolCall('bash', 'git status && npm test'),
    );
    expect(check('git status && npm test'), PermissionVerdict.allow);
  });

  test('deny 只匹配整条命令,不再解析子命令', () {
    store.rules.add(
      const PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'git status',
        effect: RuleEffect.deny,
      ),
    );

    expect(check('git status'), PermissionVerdict.deny);
    expect(check('git status && npm test'), PermissionVerdict.prompt);
  });

  test('同一 run 的完整参数授权可复用,deny 仍优先', () async {
    const args = {'command': 'git status', 'workdir': '/workspace/a'};
    await service.approveForSession(1, 'bash', args);

    expect(service.check(1, 'bash', args), PermissionVerdict.allow);
    expect(service.check(2, 'bash', args), PermissionVerdict.prompt);
    expect(
      service.check(1, 'bash', {...args, 'workdir': '/workspace/b'}),
      PermissionVerdict.prompt,
    );
    store.rules.add(
      const PermissionRule(
        tool: 'bash',
        kind: RuleKind.exact,
        pattern: 'git status',
        effect: RuleEffect.deny,
      ),
    );
    expect(service.check(1, 'bash', args), PermissionVerdict.deny);
  });

  test('文件和网址的显式规则继续生效', () {
    store.rules.addAll([
      ...PermissionRule.forToolCall('file_write', '/workspace/*.txt'),
      ...PermissionRule.forToolCall('web_fetch', 'https://example.com'),
    ]);

    expect(
      service.check(1, 'file_write', {'path': '/workspace/notes.txt'}),
      PermissionVerdict.allow,
    );
    expect(
      service.check(1, 'file_write', {'path': '/workspace/sub/notes.txt'}),
      PermissionVerdict.prompt,
    );
    expect(
      service.check(1, 'web_fetch', {'url': 'https://example.com/docs'}),
      PermissionVerdict.allow,
    );
  });

  test('web_fetch 的 origin 规则只放行不带 body / headers 的 GET', () {
    store.rules.addAll(
      PermissionRule.forToolCall('web_fetch', 'https://api.example.com'),
    );
    const url = 'https://api.example.com/gists';

    expect(service.check(1, 'web_fetch', {'url': url}), PermissionVerdict.allow);
    expect(
      service.check(1, 'web_fetch', {'url': url, 'method': 'get'}),
      PermissionVerdict.allow,
    );
    for (final args in <Map<String, dynamic>>[
      {'url': url, 'method': 'POST'},
      {'url': url, 'body': '{"public":true}'},
      {
        'url': url,
        'headers': {'Authorization': 'Bearer x'},
      },
    ]) {
      expect(
        service.check(1, 'web_fetch', args),
        PermissionVerdict.prompt,
        reason: '$args 超出了 origin 规则覆盖的范围',
      );
    }

    // 同一 run 内逐次批准过的完整调用照常复用
    final post = {'url': url, 'method': 'POST', 'body': 'x'};
    service.approveForSession(1, 'web_fetch', post);
    expect(service.check(1, 'web_fetch', post), PermissionVerdict.allow);
  });

  test('web_fetch 的 deny 规则对任何 method 都生效', () {
    store.rules.add(
      PermissionRule(
        tool: 'web_fetch',
        kind: RuleKind.origin,
        pattern: 'https://evil.example',
        effect: RuleEffect.deny,
      ),
    );
    expect(
      service.check(1, 'web_fetch', {
        'url': 'https://evil.example/x',
        'method': 'POST',
      }),
      PermissionVerdict.deny,
    );
  });

  test('读取、搜索、任务查询统一进入审批,不按工具类型免审批', () {
    for (final call in <String, Map<String, dynamic>>{
      'file_read': {'path': '/workspace/notes.txt'},
      'web_fetch': {'url': 'https://example.com'},
      'web_search': {'query': 'test'},
      'tool_output_read': {'output_id': 'test'},
      'background_task': {'action': 'list'},
      'experience_recall': {'query': 'test'},
      'sentinel_list': {},
      'sentinel_get': {'name': 'test'},
    }.entries) {
      expect(
        service.check(1, call.key, call.value),
        PermissionVerdict.prompt,
        reason: call.key,
      );
    }
  });

  test('Bash 和 PowerShell 统一串行,包括后台调用', () {
    for (final tool in <Tool>[BashShellTool(), PowerShellShellTool()]) {
      for (final command in ['ls', 'git status', 'Get-ChildItem']) {
        for (final background in [false, true]) {
          expect(
            tool.canExecuteParallel({
              'command': command,
              'background': background,
            }),
            isFalse,
            reason: '${tool.name}: $command, background=$background',
          );
        }
      }
    }
  });
}
