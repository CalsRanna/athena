import 'package:athena/agent/tool/bash_shell_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BashShellTool', () {
    final tool = BashShellTool();

    test('name is bash', () {
      expect(tool.name, 'bash');
    });

    test('dangerLevel is needsApproval', () {
      expect(tool.dangerLevel.name, 'needsApproval');
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

    test('execute returns error on bad command', () async {
      final result = await tool.execute({
        'command': 'nonexistent_command_xyz_123',
      });
      expect(result, contains('[exit code:'));
    });
  });
}
