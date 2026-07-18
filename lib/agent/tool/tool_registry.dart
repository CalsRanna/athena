import 'tool_interface.dart';

export 'tool_interface.dart' show ExecutionMode;

class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(Iterable<Tool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  Tool? get(String name) => _tools[name];

  List<Tool> get all => _tools.values.toList();

  List<Map<String, dynamic>> get definitions => _tools.values.map((t) => {
    'type': 'function',
    'function': {
      'name': t.name,
      'description': t.description,
      'parameters': t.parameters,
    },
  }).toList();
}
