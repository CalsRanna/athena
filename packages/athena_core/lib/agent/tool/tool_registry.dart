import 'package:athena_core/agent/task/background_task.dart';

import 'tool_interface.dart';
import 'tool_output_store.dart';

export 'tool_interface.dart' show ExecutionMode;

class ToolRegistry {
  ToolRegistry({
    ToolOutputStore? outputStore,
    BackgroundTaskService? backgroundTasks,
  }) : outputStore = outputStore ?? ToolOutputStore(),
       backgroundTasks = backgroundTasks ?? BackgroundTaskService();

  final ToolOutputStore outputStore;

  /// 后台任务登记表：与 [outputStore] 同级——两者都是「一次工具调用之外
  /// 仍然存在的资源」，由注册表持有，工具与协调层共用同一份。
  final BackgroundTaskService backgroundTasks;

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

  /// 单个工具的 OpenAI function schema。
  static Map<String, dynamic> definitionOf(Tool tool) => {
    'type': 'function',
    'function': {
      'name': tool.name,
      'description': tool.description,
      'parameters': parametersFor(tool),
    },
  };

  /// Model-facing schema: 业务参数 + 引擎注入的调用元数据。
  ///
  /// [toolCallDescriptionKey] 为必填——卡片 header 与审批界面都靠它展示
  /// 「这次调用在做什么」；缺失时由 [SchemaValidator] 判为参数非法并回退
  /// 给模型重发。
  static Map<String, dynamic> parametersFor(Tool tool) {
    final parameters = tool.parameters;
    final declared = parameters['required'];
    final required = <String>[
      ...(declared is List ? declared.cast<String>() : const <String>[]),
    ];
    if (!required.contains(toolCallDescriptionKey)) {
      required.add(toolCallDescriptionKey);
    }
    return {
      ...parameters,
      'properties': {
        toolCallDescriptionKey: {
          'type': 'string',
          'description':
              'Required in every tool call. '
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
      'required': required,
    };
  }

  List<Map<String, dynamic>> get definitions => _definitions ??= _tools.values
      .map(definitionOf)
      .toList();
}
