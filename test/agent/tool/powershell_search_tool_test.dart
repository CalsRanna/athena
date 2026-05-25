import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/tool/powershell_search_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PowerShellSearchTool', () {
    final tool = PowerShellSearchTool(sandbox: PathSandbox());

    test('name is search', () {
      expect(tool.name, 'search');
    });

    test('dangerLevel is safe', () {
      expect(tool.dangerLevel.name, 'safe');
    });

    test('parameters require pattern', () {
      expect(tool.parameters['required'], contains('pattern'));
    });

    test('parameters include optional path and type', () {
      final properties = tool.parameters['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('path'), isTrue);
      expect(properties.containsKey('type'), isTrue);
    });

    test('type enum contains grep and find', () {
      final properties = tool.parameters['properties'] as Map<String, dynamic>;
      final typeEnum = properties['type']['enum'] as List<dynamic>;
      expect(typeEnum, containsAll(['grep', 'find']));
    });
  });
}
