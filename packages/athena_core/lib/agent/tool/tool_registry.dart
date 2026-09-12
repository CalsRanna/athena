import 'tool_interface.dart';
import 'tool_output_store.dart';

export 'tool_interface.dart' show ExecutionMode;

class ToolRegistry {
  ToolRegistry({ToolOutputStore? outputStore})
    : outputStore = outputStore ?? ToolOutputStore();

  final ToolOutputStore outputStore;

  final Map<String, Tool> _tools = {};

  /// OpenAI tool definitions 缓存：工具集在一次 run 内不变，而 Agent
  /// 循环每轮迭代都要取一次，没必要每次重建 N 个嵌套 Map。
  List<Map<String, dynamic>>? _definitions;

  void register(Tool tool) {
    _tools[tool.name] = tool;
    _definitions = null;
  }

  void registerAll(Iterable<Tool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  Tool? get(String name) => _tools[name];

  List<Tool> get all => _tools.values.toList();

  /// Model-facing schema, including optional per-call display metadata.
  static Map<String, dynamic> parametersFor(Tool tool) {
    final parameters = tool.parameters;
    return {
      ...parameters,
      'properties': {
        toolCallDescriptionKey: {
          'type': 'string',
          'description':
              'Briefly explain this specific call in the user\'s language. '
              'Use one short, active sentence naming the action and target. '
              'For multi-step commands, describe all meaningful effects. '
              'Do not claim the action is safe or already approved. '
              'This text is shown to the user, not executed.',
        },
        toolApprovalRecommendationKey: {
          'type': 'string',
          'enum': ['proceed', 'ask'],
          'description':
              'Recommend proceed only when this exact action and all its effects '
              'are within the user\'s request or existing authorization. '
              'Use ask when a user decision or additional authorization is needed. '
              'This is a recommendation, never permission to bypass rules.',
        },
        toolApprovalReasonKey: {
          'type': 'string',
          'description':
              'Briefly explain the authorization basis or missing user decision '
              'in the user\'s language. Do not invent consent.',
        },
        ...?parameters['properties'] as Map<String, dynamic>?,
      },
    };
  }

  List<Map<String, dynamic>> get definitions => _definitions ??= _tools.values
      .map(
        (t) => {
          'type': 'function',
          'function': {
            'name': t.name,
            'description': t.description,
            'parameters': parametersFor(t),
          },
        },
      )
      .toList();
}
