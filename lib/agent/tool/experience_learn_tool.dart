import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/repository/experience_repository.dart';

/// 记录经验教训的工具，使 Agent 能从交互中持续学习。
///
/// Agent 可以在对话过程中或对话结束后调用此工具，
/// 将学到的教训、发现的模式、或用户的重要偏好记录下来。
/// 这些经验可以在未来的对话中通过 `experience_recall` 工具检索。
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
      'Recorded experiences can be recalled later with experience_recall.';

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
        },
        'required': ['lesson'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final lesson = args['lesson'] as String;
    final context = args['context'] as String? ?? '';
    final tagsStr = args['tags'] as String? ?? '';
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
      );
      return 'Experience recorded successfully (id: ${entity.id}). '
          'Total experiences: ${_repository.count}. '
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
class ExperienceRecallTool implements Tool {
  final ExperienceRepository _repository;

  ExperienceRecallTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  String get name => 'experience_recall';

  @override
  String get description =>
      'Search and recall past experiences, lessons, and insights you have '
      'recorded. Use this to inform your approach to current tasks by '
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
        },
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    final limit = args['limit'] as int? ?? 10;

    try {
      final results = query.trim().isEmpty
          ? _repository.listAll()
          : _repository.search(query.trim());

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
        buffer.writeln('--- Experience ${i + 1} ---');
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
