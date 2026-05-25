import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/tool/powershell_shell_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PowerShellShellTool', () {
    final tool = PowerShellShellTool(sandbox: PathSandbox());

    test('name is powershell', () {
      expect(tool.name, 'powershell');
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

    test('description mentions PowerShell', () {
      expect(tool.description.toLowerCase(), contains('powershell'));
    });
  });
}
