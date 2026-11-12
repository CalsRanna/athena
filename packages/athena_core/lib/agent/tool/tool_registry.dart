import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';

export 'package:athena_core/agent/tool/tool_interface.dart' show ExecutionMode;

class ToolRegistry {
  final ToolOutputStore outputStore;

  /// 后台任务登记表：与 [outputStore] 同级——两者都是「一次工具调用之外
  /// 仍然存在的资源」，由注册表持有，工具与协调层共用同一份。
  final BackgroundTaskService backgroundTasks;

  final Map<String, Tool> _tools;

  /// 本视图相对完整注册表被排除的工具名；完整注册表为 null。
  final Set<String>? _excluded;

  /// OpenAI tool definitions 缓存：工具集在一次 run 内不变，而 Agent
  /// 循环每轮迭代都要取一次，没必要每次重建 N 个嵌套 Map。
  List<Map<String, dynamic>>? _definitions;

  ToolRegistry({
    ToolOutputStore? outputStore,
    BackgroundTaskService? backgroundTasks,
  }) : this._(
         outputStore ?? ToolOutputStore(),
         backgroundTasks ?? BackgroundTaskService(),
         {},
       );

  ToolRegistry._(
    this.outputStore,
    this.backgroundTasks,
    this._tools, {
    Set<String>? excluded,
  }) : _excluded = excluded;

  List<Tool> get all => _tools.values.toList();

  List<Map<String, dynamic>> get definitions =>
      _definitions ??= _tools.values.map(definitionOf).toList();

  /// 生成一次 run 的受限视图：只保留 [enabled] 中的工具（null = 不限制）。
  ///
  /// 视图共享 [outputStore] 与 [backgroundTasks]：这两者是跨调用资源，
  /// 不能按角色分裂。被排除的工具 [get] 返回 null；[isExcluded] 用来把
  /// 「本角色禁用」与「根本没有这个工具」区分开。
  ToolRegistry filtered({Set<String>? enabled}) {
    if (enabled == null) return this;
    return ToolRegistry._(
      outputStore,
      backgroundTasks,
      {
        for (final entry in _tools.entries)
          if (enabled.contains(entry.key)) entry.key: entry.value,
      },
      excluded: {
        for (final name in _tools.keys)
          if (!enabled.contains(name)) name,
      },
    );
  }

  Tool? get(String name) => _tools[name];

  /// 该工具名是否因本次 run 的工具配置而被排除。
  bool isExcluded(String name) => _excluded?.contains(name) ?? false;

  void register(Tool tool) {
    _tools[tool.name] = tool;
    _definitions = null;
  }

  void registerAll(Iterable<Tool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

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
  /// [ToolArguments.toolCallDescriptionKey] 为必填——卡片 header 与审批界面都靠它展示
  /// 「这次调用在做什么」；缺失时由 [SchemaValidator] 判为参数非法并回退
  /// 给模型重发。
  static Map<String, dynamic> parametersFor(Tool tool) {
    final parameters = tool.parameters;
    final declared = parameters['required'];
    final required = <String>[
      ...(declared is List ? declared.cast<String>() : const <String>[]),
    ];
    if (!required.contains(ToolArguments.toolCallDescriptionKey)) {
      required.add(ToolArguments.toolCallDescriptionKey);
    }
    return {
      ...parameters,
      'properties': {
        ToolArguments.toolCallDescriptionKey: {
          'type': 'string',
          'description':
              'Required in every tool call. '
              'Briefly explain this specific call in the user\'s language. '
              'Use one short, active sentence naming the action and target. '
              'For multi-step commands, describe all meaningful effects. '
              'Do not claim the action is safe or already approved. '
              'This text is shown to the user, not executed.',
        },
        ...?parameters['properties'] as Map<String, dynamic>?,
      },
      'required': required,
    };
  }
}
