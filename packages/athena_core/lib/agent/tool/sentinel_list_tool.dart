import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// 列出全部 Sentinel（角色的只读工具。
///
/// 返回轻量元数据（名称、描述、标签、头像），**不含** prompt 全文——
/// 需要完整内容（含 prompt）时用 sentinel_get。结果按名称排序,
/// 保证输出稳定可复现。
class SentinelListTool implements Tool {
  final SentinelRepository _repository;

  SentinelListTool({required SentinelRepository repository})
      : _repository = repository;

  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get name => 'sentinel_list';

  @override
  String get description =>
      'List all sentinels (role definitions / system prompts) with their '
      'name, description, tags, and avatar — but NOT the full prompt. '
      'Use this to discover which sentinels exist before evolving one. '
      'Call sentinel_get with a name to see its full prompt.';

  @override
  Map<String, dynamic> get parameters => <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      };

  @override
  Future<String> execute(Map<String, dynamic> args,
      {void Function(String)? onUpdate}) async {
    final sentinels = await _repository.getAllSentinels();
    if (sentinels.isEmpty) {
      return 'No sentinels found.';
    }
    final sorted = List<SentinelEntity>.from(sentinels)
      ..sort((a, b) => a.name.compareTo(b.name));
    final buffer = StringBuffer();
    buffer.writeln('Available sentinels (${sorted.length}):');
    buffer.writeln();
    for (final s in sorted) {
      buffer.writeln('- **${s.name}**'
          '${s.isListVisible ? '' : ' (hidden preset)'}');
      if (s.description.trim().isNotEmpty) {
        buffer.writeln(
            '  Description: ${_oneLine(s.description)}');
      }
      final tagList = s.tagList;
      if (tagList.isNotEmpty) {
        buffer.writeln('  Tags: ${tagList.join(', ')}');
      }
      if (s.avatar.trim().isNotEmpty) {
        buffer.writeln('  Avatar: ${s.avatar}');
      }
    }
    buffer.writeln();
    buffer.writeln('Use sentinel_get <name> to view the full prompt of a '
        'specific sentinel.');
    return buffer.toString();
  }

  /// 折叠为单行（description 可能含换行）。
  String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
