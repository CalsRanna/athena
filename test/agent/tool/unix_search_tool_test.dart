import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/tool/unix_search_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnixSearchTool', () {
    final tool = UnixSearchTool(sandbox: PathSandbox());

    test('name is search', () {
      expect(tool.name, 'search');
    });

    test('dangerLevel is needsApproval', () {
      expect(tool.dangerLevel.name, 'needsApproval');
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

    test('execute grep returns results for a known string', () async {
      final result = await tool.execute({
        'pattern': r'dart:io',
        'path': 'lib/agent/tool',
        'type': 'grep',
      });
      expect(result, contains('dart:io'));
    });

    test('execute find returns results for a known file', () async {
      final result = await tool.execute({
        'pattern': '*.dart',
        'path': 'lib/agent/tool',
        'type': 'find',
      });
      expect(result, contains('.dart'));
    });
  });
}
