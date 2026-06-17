import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/repository/experience_repository.dart';

/// 记录经验教训的工具，使 Agent 能从交互中持续学习。
///
/// Agent 可以在对话过程中或对话结束后调用此工具，
/// 将学到的教训、发现的模式、或用户的重要偏好记录下来。
///
/// 每条经验属于当前 Sentinel（scope="self"），或标记为全局共享（scope="shared"）。
/// shared 经验对所有 Sentinel 可见，适用于用户通用偏好、沟通风格等跨域信息。
class ExperienceLearnTool implements Tool {
  final ExperienceRepository _repository;

  ExperienceLearnTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  String get name => 'experience_learn';

  @override
  String get description =>
      'Record a lesson, insight, or pattern learned from the current '
      'interaction. This builds your long-term memory of effective strategies, '
      'user preferences, and common pitfalls. Use this when:\n'
      '- You discovered a better way to solve a type of problem\n'
      '- The user corrected your approach and you want to remember it\n'
      '- You identified a recurring pattern that could inform future responses\n'
      '- You want to remember the user\'s preferences or conventions\n'
      'Recorded experiences can be recalled later with experience_recall.\n'
      'By default, experiences are private to your current Sentinel role. '
      'Use scope="shared" only for universal user preferences or '
      'communication style that other roles should also know.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'lesson': {
            'type': 'string',
            'description':
                'The lesson or insight to remember. Be specific and actionable. '
                'Include the context: what was the situation, what went wrong '
                '(or right), and what should be done differently in the future.',
          },
          'context': {
            'type': 'string',
            'description':
                'Brief description of the situation that led to this lesson '
                '(e.g., "Building a Flutter widget", "Debugging API errors"). '
                'Helps with future retrieval.',
          },
          'tags': {
            'type': 'string',
            'description':
                'Comma-separated tags for categorization and retrieval '
                '(e.g., "flutter, state-management, best-practice").',
          },
          'scope': {
            'type': 'string',
            'description':
                'Scope of this experience. "self" (default): only visible to '
                'your current Sentinel role. "shared": visible to all Sentinel '
                'roles. Use "shared" for universal user preferences, '
                'communication style, or personal info that applies across '
                'contexts. Use "self" for tool-specific tricks or '
                'domain-specific patterns.',
            'enum': ['self', 'shared'],
          },
        },
        'required': ['lesson'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final lesson = args['lesson'] as String;
    final context = args['context'] as String? ?? '';
    final tagsStr = args['tags'] as String? ?? '';
    final scope = args['scope'] as String? ?? 'self';
    final sentinelId = args['_sentinel_id'] as String? ?? 'default';
    final tags = tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (lesson.trim().isEmpty) {
      return 'Error: lesson must not be empty.';
    }

    try {
      final entity = await _repository.save(
        lesson: lesson.trim(),
        context: context.trim(),
        tags: tags,
        source: 'auto',
        scope: scope,
        sentinelId: sentinelId,
      );
      return 'Experience recorded successfully (id: ${entity.id}, '
          'scope: ${entity.scope}). '
          'This knowledge will be available in future conversations.';
    } catch (e) {
      return 'Error recording experience: $e';
    }
  }
}

/// 检索过往经验的工具。
///
/// Agent 可以在开始新任务时检索相关经验，
/// 以便利用过去的教训和洞察来改进当前的表现。
///
/// 默认检索当前 Sentinel 的私有经验 + shared 经验。
class ExperienceRecallTool implements Tool {
  final ExperienceRepository _repository;

  ExperienceRecallTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  String get name => 'experience_recall';

  @override
  String get description =>
      'Search and recall past experiences, lessons, and insights. '
      'Searches both your private experiences (specific to your current '
      'Sentinel role) and shared experiences (universal user preferences). '
      'Use this to inform your approach to current tasks by '
      'leveraging past learnings. Call this when:\n'
      '- Starting a task similar to ones you\'ve done before\n'
      '- Looking for established patterns or user preferences\n'
      '- You want to avoid repeating past mistakes\n'
      'Provide a query string to search, or omit to list all experiences.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Search query to find relevant experiences. Matches against '
                'lesson text, context, and tags. Omit to list all experiences.',
          },
          'limit': {
            'type': 'integer',
            'description':
                'Maximum number of experiences to return (default: 10).',
          },
          'include_shared': {
            'type': 'boolean',
            'description':
                'Whether to include shared experiences in results '
                '(default: true). Set to false to search only your private '
                'experiences.',
          },
        },
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    final limit = args['limit'] as int? ?? 10;
    final includeShared = args['include_shared'] as bool? ?? true;
    final sentinelId = args['_sentinel_id'] as String? ?? 'default';

    try {
      final results = includeShared
          ? (query.trim().isEmpty
              ? _repository.listForSentinel(sentinelId)
              : _repository.searchForSentinel(sentinelId, query.trim()))
          : (query.trim().isEmpty
              ? _repository.listPrivate(sentinelId)
              : _repository.searchPrivate(sentinelId, query.trim()));

      if (results.isEmpty) {
        return query.isEmpty
            ? 'No experiences recorded yet. Use experience_learn to start building your knowledge base.'
            : 'No experiences found matching "$query".';
      }

      final buffer = StringBuffer();
      final display = results.take(limit).toList();
      buffer.writeln(
          'Found ${results.length} experience(s)${query.isNotEmpty ? ' matching "$query"' : ''}'
          '${results.length > limit ? ' (showing $limit)' : ''}:');
      buffer.writeln();

      for (var i = 0; i < display.length; i++) {
        final e = display[i];
        final origin = e.scope == 'shared' ? 'shared' : 'private';
        buffer.writeln('--- Experience ${i + 1} ($origin) ---');
        buffer.writeln('ID: ${e.id}');
        buffer.writeln('Date: ${_formatDate(e.createdAt)}');
        if (e.context.isNotEmpty) {
          buffer.writeln('Context: ${e.context}');
        }
        if (e.tags.isNotEmpty) {
          buffer.writeln('Tags: ${e.tags.join(', ')}');
        }
        buffer.writeln('Lesson: ${e.lesson}');
        buffer.writeln();
      }

      return buffer.toString().trim();
    } catch (e) {
      return 'Error recalling experiences: $e';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
