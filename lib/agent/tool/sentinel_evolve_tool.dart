import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/repository/sentinel_repository.dart';

/// 优化 Sentinel（系统提示词）的工具，使 Agent 能基于使用反馈改进自身角色设定。
///
/// Agent 直接修改当前使用的 Sentinel，在原有基础上改进其提示词、
/// 描述等信息，而不是创建新的 Sentinel。可选支持重命名。
class SentinelEvolveTool implements Tool {
  /// 内置 sentinel 的名称，其内容可改进但名称不可修改
  static const builtinSentinelName = 'Athena';

  final SentinelRepository _repository;
  final void Function()? _onChanged;

  SentinelEvolveTool({
    required SentinelRepository repository,
    void Function()? onChanged,
  })  : _repository = repository,
        _onChanged = onChanged;

  @override
  String get name => 'sentinel_evolve';

  @override
  String get description =>
      'Improve an existing sentinel (system prompt / role definition) in place. '
      'Use this to refine how you operate in a specific role based on experience. '
      'This enables:\n'
      '- Fixing issues in the current sentinel\'s instructions\n'
      '- Adding missing capabilities or constraints\n'
      '- Refining the tone, workflow, or output format\n'
      '- Adapting the role based on user feedback patterns\n'
      '- Optionally renaming the sentinel\n'
      'The sentinel is updated directly — no duplicate is created. '
      'Always explain what changes you made and why.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sentinel_name': {
            'type': 'string',
            'description':
                'The name of the existing sentinel to improve. Use the exact '
                'name as shown in the sentinel list.',
          },
          'new_name': {
            'type': 'string',
            'description':
                'New name for the sentinel (optional). If provided and '
                'different from the original, the sentinel will be renamed. '
                'If omitted, the sentinel keeps its current name.',
          },
          'improvements': {
            'type': 'string',
            'description':
                'Summary of what was improved and why. This helps the user '
                'understand the changes.',
          },
          'new_prompt': {
            'type': 'string',
            'description':
                'The complete, improved system prompt. This is the full '
                'replacement prompt incorporating all improvements.',
          },
          'new_description': {
            'type': 'string',
            'description':
                'Updated description for the sentinel (optional, '
                'defaults to current description).',
          },
          'new_tags': {
            'type': 'string',
            'description':
                'Comma-separated tags for the sentinel (optional, '
                'defaults to current tags).',
          },
          'new_avatar': {
            'type': 'string',
            'description':
                'Emoji avatar for the sentinel (optional, defaults to current).',
          },
        },
        'required': ['sentinel_name', 'improvements', 'new_prompt'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final sentinelName = args['sentinel_name'] as String;
    final newName = args['new_name'] as String?;
    final improvements = args['improvements'] as String;
    final newPrompt = args['new_prompt'] as String;
    final newDescription = args['new_description'] as String?;
    final newTags = args['new_tags'] as String?;
    final newAvatar = args['new_avatar'] as String?;

    // 查找原 sentinel
    final original = await _repository.getSentinelByName(sentinelName);
    if (original == null) {
      return 'Error: Sentinel "$sentinelName" not found. '
          'Check the name spelling. Available sentinels can be listed in the '
          'settings.';
    }

    if (newPrompt.trim().isEmpty) {
      return 'Error: new_prompt must not be empty.';
    }

    // 内置 sentinel 不允许改名
    if (original.name == builtinSentinelName) {
      final requestedName =
          (newName != null && newName.isNotEmpty) ? newName : original.name;
      if (requestedName != builtinSentinelName) {
        return 'Error: The built-in "$builtinSentinelName" sentinel cannot be '
            'renamed. You can improve its prompt, description, tags, and avatar, '
            'but the name must remain "$builtinSentinelName".';
      }
    }

    try {
      final effectiveName =
          (newName != null && newName.isNotEmpty) ? newName : original.name;

      // 如果改名且新名称与当前名称不同，检查是否与其他 sentinel 冲突
      if (effectiveName != original.name) {
        final conflict = await _repository.getSentinelByName(effectiveName);
        if (conflict != null && conflict.id != original.id) {
          return 'Error: A different sentinel named "$effectiveName" already '
              'exists. Choose a different name.';
        }
      }

      final avatar = newAvatar != null && newAvatar.isNotEmpty
          ? newAvatar
          : original.avatar;
      final tags = newTags ?? original.tags;
      final description = newDescription != null && newDescription.isNotEmpty
          ? newDescription
          : original.description;

      // 在原 sentinel 基础上修改（保留原始 id）
      final updated = original.copyWith(
        name: effectiveName,
        description: description,
        prompt: newPrompt,
        avatar: avatar,
        tags: tags,
      );

      // 更新到数据库
      await _repository.updateSentinel(updated);
      _onChanged?.call();

      // 生成变更摘要
      final changeReport = _buildChangeReport(
        originalName: sentinelName,
        newName: effectiveName,
        improvements: improvements,
        originalPrompt: original.prompt,
        newPrompt: newPrompt,
      );

      return 'Sentinel evolved successfully!\n'
          'Updated "$sentinelName"'
          '${effectiveName != sentinelName ? ' → "$effectiveName"' : ''}.\n\n'
          '$changeReport\n\n'
          'The sentinel has been updated in place. '
          'The changes take effect immediately in the current chat.';
    } catch (e) {
      return 'Error updating sentinel: $e';
    }
  }

  String _buildChangeReport({
    required String originalName,
    required String newName,
    required String improvements,
    required String originalPrompt,
    required String newPrompt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('## Evolution Report');
    buffer.writeln();
    if (originalName != newName) {
      buffer.writeln('**From:** $originalName → **To:** $newName');
    } else {
      buffer.writeln('**Sentinel:** $originalName (updated in place)');
    }
    buffer.writeln();
    buffer.writeln('**Improvements:**');
    buffer.writeln(improvements);
    buffer.writeln();
    buffer.writeln('**Changes:**');
    buffer.writeln(
        '- Original prompt length: ${originalPrompt.length} chars');
    buffer.writeln('- New prompt length: ${newPrompt.length} chars');
    buffer.writeln(
        '- Difference: ${newPrompt.length - originalPrompt.length} chars');
    return buffer.toString();
  }
}
