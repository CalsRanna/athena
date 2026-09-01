import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// 按名称查询单个 Sentinel 的详情（只读工具）。
///
/// 返回完整内容（含 prompt 全文），供 sentinel_evolve 前对照当前
/// 提示词;也可用于确认某个名字/描述是否如预期。名字来自
/// sentinel_list 的输出。
class SentinelGetTool implements Tool {
  final SentinelRepository _repository;

  SentinelGetTool({required SentinelRepository repository})
      : _repository = repository;

  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get name => 'sentinel_get';

  @override
  String get description =>
      'Get the full details of a single sentinel by its exact name, '
      'including the complete prompt. Use sentinel_list first to discover '
      'existing sentinel names.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sentinel_name': {
            'type': 'string',
            'description':
                'The exact name of the sentinel to fetch (as shown in '
                'sentinel_list).',
          },
        },
        'required': ['sentinel_name'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args,
      {void Function(String)? onUpdate}) async {
    final name = (args['sentinel_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return 'Error: sentinel_name must not be empty.';
    }

    final sentinel = await _repository.getSentinelByName(name);
    if (sentinel == null) {
      return 'Error: Sentinel "$name" not found. '
          'Run sentinel_list to see available sentinels.';
    }

    final buffer = StringBuffer();
    buffer.writeln('**${sentinel.name}**');
    buffer.writeln('- Name: ${sentinel.name}');
    buffer.writeln('- Avatar: ${sentinel.avatar.isEmpty ? '(none)' : sentinel.avatar}');
    buffer.writeln('- Tags: ${sentinel.tags.isEmpty ? '(none)' : sentinel.tags}');
    buffer.writeln(
        '- Description: ${sentinel.description.isEmpty ? '(none)' : sentinel.description}');
    buffer.writeln('- Preset: ${sentinel.isPreset}');
    buffer.writeln();
    buffer.writeln('**Prompt:**');
    buffer.writeln(sentinel.prompt.isEmpty ? '(empty)' : sentinel.prompt);
    return buffer.toString();
  }
}
