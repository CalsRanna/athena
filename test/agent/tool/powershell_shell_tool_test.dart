import 'package:athena/agent/tool/powershell_shell_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PowerShellShellTool', () {
    final tool = PowerShellShellTool();

    test('name is powershell', () {
      expect(tool.name, 'powershell');
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

    test('blocks recursive delete command', () async {
      final result = await tool.execute({
        'command': 'Remove-Item -Path C:\\test -Recurse',
      });
      expect(result, contains('Warning'));
    });
  });
}
