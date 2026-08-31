import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';

/// 记录经验教训的工具，使 Agent 能从交互中持续学习。
///
/// Agent 可以在对话过程中或对话结束后调用此工具，
/// 将学到的教训、发现的模式、或用户的重要偏好记录下来。
///
/// 每条经验属于当前 Sentinel（scope="self"），或标记为全局共享（scope="shared"）。
/// shared 经验对所有 Sentinel 可见，适用于用户通用偏好、沟通风格等跨域信息。
///
/// 支持完整生命周期：create（记录）/ update（修正）/ archive（归档为反例）。
class ExperienceLearnTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  final ExperienceRepository _repository;

  ExperienceLearnTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get name => 'experience_learn';

  @override
  String get description =>
      'Record a lesson, insight, or pattern learned from the current '
      'interaction. This builds your long-term memory of effective strategies, '
      'user preferences, and common pitfalls.\n'
      'Actions:\n'
      '- create (default): record a new experience\n'
      '- update: revise an existing experience (wrong or outdated lesson, '
      'missing tags). Requires experience_id.\n'
      '- archive: stop recalling an existing experience while keeping it as a '
      'record (e.g. a lesson the user refuted). Requires experience_id.\n'
      'Use this when:\n'
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
          'action': {
            'type': 'string',
            'enum': ['create', 'update', 'archive'],
            'description': 'What to do with the experience. create (default): '
                'record a new one. update: fix an existing one (requires '
                'experience_id). archive: stop recalling an existing one while '
                'keeping it as a record (requires experience_id).',
          },
          'experience_id': {
            'type': 'string',
            'description': 'ID of the experience to update or archive. '
                'Required when action is "update" or "archive"; must be '
                'omitted when action is "create".',
          },
          'lesson': {
            'type': 'string',
            'description':
                'For create: the lesson or insight to remember. Be specific '
                'and actionable. Include the context: what was the situation, '
                'what went wrong (or right), and what should be done '
                'differently in the future.\n'
                'For update: the revised lesson (omit to keep the current one).',
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
                'domain-specific patterns.\n'
                'For update: changing the scope moves the experience between '
                'the private and shared store.',
            'enum': ['self', 'shared'],
          },
        },
        'required': ['lesson'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final lesson = args['lesson'] as String? ?? '';
    final context = args['context'] as String? ?? '';
    final tagsStr = args['tags'] as String? ?? '';
    final scope = args['scope'] as String? ?? 'self';
    final action = args['action'] as String? ?? 'create';
    final experienceId = args['experience_id'] as String?;
    final sentinelId = args['_sentinel_id'] as String? ?? 'default';
    final tags = tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (!const ['create', 'update', 'archive'].contains(action)) {
      return 'Error: Unknown action "$action". Use "create", "update", or '
          '"archive".';
    }

    try {
      if (action == 'create') {
        if (experienceId != null && experienceId.isNotEmpty) {
          return 'Error: experience_id must be omitted when action is "create". '
              'Use action "update" to modify an existing experience.';
        }
        if (lesson.trim().isEmpty) {
          return 'Error: lesson must not be empty when creating an experience.';
        }
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
      }

      if (experienceId == null || experienceId.isEmpty) {
        return 'Error: experience_id is required for action "$action".';
      }

      if (action == 'update') {
        final updated = await _repository.update(
          sentinelId: sentinelId,
          id: experienceId,
          lesson: lesson.isEmpty ? null : lesson,
          context: context.isEmpty ? null : context,
          tags: tags.isEmpty ? null : tags,
          scope: scope,
        );
        if (updated == null) {
          return 'Error: Experience "$experienceId" not found. It may belong '
              'to a different Sentinel or have been deleted.';
        }
        return 'Experience updated successfully (id: ${updated.id}, '
            'scope: ${updated.scope}).';
      }

      // action == 'archive'
      final archived = await _repository.update(
        sentinelId: sentinelId,
        id: experienceId,
        status: ExperienceEntity.statusArchived,
      );
      if (archived == null) {
        return 'Error: Experience "$experienceId" not found. It may belong '
            'to a different Sentinel or have been deleted.';
      }
      return 'Experience archived (id: ${archived.id}). It will no longer '
          'appear in experience_recall results by default, but remains '
          'stored as a record.';
    } catch (e) {
      return 'Error $action experience: $e';
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
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  final ExperienceRepository _repository;

  ExperienceRecallTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get name => 'experience_recall';

  @override
  String get description =>
      'Search and recall past experiences, lessons, and insights. '
      'Searches both your private experiences (specific to your current '
      'Sentinel role) and shared experiences (universal user preferences). '
      'Results are ranked by relevance to your query, not by recency. '
      'Archived experiences are excluded unless include_archived is true. '
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
          'include_archived': {
            'type': 'boolean',
            'description':
                'Whether to include archived (refuted or retired) experiences '
                'in results (default: false). Archived experiences are kept as '
                'records — mainly useful for reviewing what was rejected.',
          },
        },
        'required': <String>[],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final query = args['query'] as String? ?? '';
    final limit = args['limit'] as int? ?? 10;
    final includeShared = args['include_shared'] as bool? ?? true;
    final includeArchived = args['include_archived'] as bool? ?? false;
    final sentinelId = args['_sentinel_id'] as String? ?? 'default';

    try {
      final results = includeShared
          ? (query.trim().isEmpty
              ? await _repository.listForSentinel(sentinelId,
                  includeArchived: includeArchived)
              : await _repository.searchForSentinel(sentinelId, query.trim(),
                  includeArchived: includeArchived))
          : (query.trim().isEmpty
              ? await _repository.listPrivate(sentinelId,
                  includeArchived: includeArchived)
              : await _repository.searchPrivate(sentinelId, query.trim(),
                  includeArchived: includeArchived));

      if (results.isEmpty) {
        return query.isEmpty
            ? 'No active experiences recorded yet. Use experience_learn to '
                'start building your knowledge base.'
            : 'No active experiences found matching "$query".';
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
        final flags = <String>[
          if (e.status == ExperienceEntity.statusArchived) 'archived',
          if (e.userVerdict == ExperienceEntity.verdictConfirmed)
            'user-confirmed',
          if (e.userVerdict == ExperienceEntity.verdictRefuted) 'user-refuted',
        ];
        final annotation =
            flags.isEmpty ? '' : ' [${flags.join(', ')}]';
        buffer.writeln('--- Experience ${i + 1} ($origin)$annotation ---');
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
