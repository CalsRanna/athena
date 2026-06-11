import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/repository/sentinel_repository.dart';

/// 优化 Sentinel（系统提示词）的工具，使 Agent 能基于使用反馈改进自身角色设定。
///
/// Agent 可以在使用某个 Sentinel 一段时间后，分析其表现并提出改进版本。
/// 改进后的 Sentinel 作为新版本保存，用户可选择是否采纳。
class SentinelEvolveTool implements Tool {
  final SentinelRepository _sentinelRepository;

  SentinelEvolveTool({required SentinelRepository sentinelRepository})
      : _sentinelRepository = sentinelRepository;

  @override
  String get name => 'sentinel_evolve';

  @override
  String get description =>
      'Create an improved version of a sentinel (system prompt / role '
      'definition). Use this to refine how you operate in a specific role '
      'based on experience. This enables:\n'
      '- Fixing issues in the current sentinel\'s instructions\n'
      '- Adding missing capabilities or constraints\n'
      '- Refining the tone, workflow, or output format\n'
      '- Adapting the role based on user feedback patterns\n'
      'The improved sentinel is saved as a new entry for user review. '
      'Always explain what changes you made and why.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'sentinel_name': {
            'type': 'string',
            'description':
                'The name of the existing sentinel to improve. Use the exact name as shown in the sentinel list.',
          },
          'new_name': {
            'type': 'string',
            'description':
                'Name for the improved sentinel. Should differ from the original '
                'to distinguish versions (e.g., append "v2" or a descriptive suffix).',
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
                'Updated description for the improved sentinel (optional, '
                'defaults to description of improvements).',
          },
          'new_tags': {
            'type': 'string',
            'description':
                'Comma-separated tags for the new sentinel (optional).',
          },
          'new_avatar': {
            'type': 'string',
            'description':
                'Emoji avatar for the new sentinel (optional, defaults to original).',
          },
        },
        'required': ['sentinel_name', 'new_name', 'improvements', 'new_prompt'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final sentinelName = args['sentinel_name'] as String;
    final newName = args['new_name'] as String;
    final improvements = args['improvements'] as String;
    final newPrompt = args['new_prompt'] as String;
    final newDescription =
        args['new_description'] as String? ?? improvements;
    final newTags = args['new_tags'] as String? ?? '';
    final newAvatar = args['new_avatar'] as String? ?? '';

    // 查找原 sentinel
    final original = await _sentinelRepository.getSentinelByName(sentinelName);
    if (original == null) {
      return 'Error: Sentinel "$sentinelName" not found. '
          'Check the name spelling. Available sentinels can be listed in the settings.';
    }

    // 检查新名称是否已存在
    final existing = await _sentinelRepository.getSentinelByName(newName);
    if (existing != null) {
      return 'Error: A sentinel named "$newName" already exists. '
          'Choose a different name for the improved version.';
    }

    if (newPrompt.trim().isEmpty) {
      return 'Error: new_prompt must not be empty.';
    }

    try {
      final avatar = newAvatar.isNotEmpty ? newAvatar : original.avatar;
      final tags = newTags.isNotEmpty ? newTags : original.tags;

      // 构建改进版 sentinel
      final improved = original.copyWith(
        name: newName,
        description: newDescription,
        prompt: newPrompt,
        avatar: avatar,
        tags: tags,
      );

      // 保存
      final id = await _sentinelRepository.createSentinel(improved);

      // 生成变更摘要
      final changeReport = _buildChangeReport(
        originalName: sentinelName,
        newName: newName,
        improvements: improvements,
        originalPrompt: original.prompt,
        newPrompt: newPrompt,
      );

      return 'Sentinel evolved successfully!\n'
          'Created "$newName" (id: $id) based on "$sentinelName".\n\n'
          '$changeReport\n\n'
          'The improved sentinel is now available in your sentinel list. '
          'You can switch to it in chat settings to use the improved version.';
    } catch (e) {
      return 'Error creating improved sentinel: $e';
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
    buffer.writeln('**From:** $originalName → **To:** $newName');
    buffer.writeln();
    buffer.writeln('**Improvements:**');
    buffer.writeln(improvements);
    buffer.writeln();
    buffer.writeln('**Changes:**');
    buffer.writeln('- Original prompt length: ${originalPrompt.length} chars');
    buffer.writeln('- New prompt length: ${newPrompt.length} chars');
    buffer.writeln('- Difference: ${newPrompt.length - originalPrompt.length} chars');
    return buffer.toString();
  }
}
