import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:test/test.dart';

void main() {
  group('BashShellTool', () {
    final tool = BashShellTool();

    test('name is bash', () {
      expect(tool.name, 'bash');
    });

    test('parameters require command', () {
      expect(tool.parameters['required'], contains('command'));
    });

    test('parameters include optional timeout and workdir', () {
      final properties = tool.parameters['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('timeout'), isTrue);
      expect(properties.containsKey('workdir'), isTrue);
    });

    test('execute returns output from echo', () async {
      final result = await tool.execute({'command': 'echo hello'});
      expect(result, contains('hello'));
      expect(result, contains('[exit code: 0]'));
    });

    test('blocks recursive delete command', () async {
      final result = await tool.execute({'command': 'rm -rf /tmp/test'});
      expect(result, contains('Warning'));
      expect(result, contains('recursive delete'));
    });

    test('blocks recursive delete variants', () async {
      for (final cmd in [
        'rm --recursive /tmp/test',
        'find / -name "*.log" -exec rm {} \\;',
        'del /s C:\\Temp',
        'Remove-Item -Recurse C:\\Temp',
        'remove-item -recurse C:\\Temp',
        'rd /s C:\\Temp',
        // 绕过变体：find -delete、PowerShell 短参数与别名、rd -R
        'find . -delete',
        'find . -name "*.tmp" -delete',
        'find . -ok rm {} \\;',
        'ri -r C:\\Temp',
        'rd -r C:\\Temp',
        'Remove-Item -R C:\\Temp',
        'rd -Recurse C:\\Temp',
      ]) {
        final result = await tool.execute({'command': cmd});
        expect(result, contains('Warning'), reason: '应拦截: $cmd');
        expect(result, contains('recursive delete'), reason: cmd);
      }
    });

    test('does not block non-recursive deletes or lookalike paths', () async {
      final result = await tool.execute({'command': 'rm -f /tmp/single.txt'});
      expect(result, isNot(contains('recursive delete')));
      // 形如 rd/s 的路径写法不应被误拦（但会真实执行，退出码任意即可）
      final lookalike = await tool.execute({'command': 'echo rd/s'});
      expect(lookalike, isNot(contains('recursive delete')));
    });

    test('execute returns error on bad command', () async {
      final result = await tool.execute({
        'command': 'nonexistent_command_xyz_123',
      });
      expect(result, contains('[exit code:'));
    });

    test('defaultWorkdir is used when workdir arg is absent', () async {
      final tool = BashShellTool(defaultWorkdir: '/tmp');
      final result = await tool.execute({'command': 'pwd'});
      expect(result, contains('/tmp'));
      expect(result, contains('[exit code: 0]'));
    });

    test('explicit workdir arg overrides defaultWorkdir', () async {
      final tool = BashShellTool(defaultWorkdir: '/tmp');
      final result = await tool.execute({
        'command': 'pwd',
        'workdir': '/',
      });
      expect(result, startsWith('/\n'));
    });

    test('defaultWorkdir appears in workdir param description', () {
      final tool = BashShellTool(defaultWorkdir: '/tmp');
      final properties = tool.parameters['properties'] as Map<String, dynamic>;
      final workdirDesc = (properties['workdir'] as Map<String, dynamic>)['description']
          as String;
      expect(workdirDesc, contains('/tmp'));
    });
  });
}
