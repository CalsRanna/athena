import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';

/// 记录用户对经验的验证结论：confirm（用户明确认可）/ refute（用户明确证伪）。
///
/// 这是经验库唯一的外部验证信号源——结论必须来自用户，而不是 Agent 的
/// 自评。被 refute 的经验应随后用 experience_learn archive 归档。
class ExperienceReviewTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  final ExperienceRepository _repository;

  ExperienceReviewTool({required ExperienceRepository repository})
      : _repository = repository;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get name => 'experience_review';

  @override
  String get description =>
      'Record the user\'s verdict on a recorded experience: confirm when the '
      'user explicitly validates a lesson, refute when the user explicitly '
      'corrects it. The verdict must come from the user, never from your own '
      'assessment. '
      'Use this when:\n'
      '- The user says a past lesson or pattern was right (confirm)\n'
      '- The user says a past lesson or pattern was wrong (refute)\n'
      'After refuting, consider archiving the experience with '
      'experience_learn (action="archive").';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['confirm', 'refute'],
            'description': 'confirm: the user endorsed this experience. '
                'refute: the user contradicted it.',
          },
          'experience_id': {
            'type': 'string',
            'description':
                'ID of the experience to update (shown in experience_recall '
                'results).',
          },
          'note': {
            'type': 'string',
            'description':
                'Optional short note from the user explaining the verdict '
                '(e.g. "The user said they prefer short answers").',
          },
        },
        'required': ['action', 'experience_id'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final action = args['action'] as String? ?? '';
    final experienceId = args['experience_id'] as String? ?? '';
    final note = args['note'] as String?;
    final sentinelId = args['_sentinel_id'] as String? ?? 'default';

    final String verdict;
    if (action == 'confirm') {
      verdict = ExperienceEntity.verdictConfirmed;
    } else if (action == 'refute') {
      verdict = ExperienceEntity.verdictRefuted;
    } else {
      return 'Error: action must be "confirm" or "refute".';
    }

    if (experienceId.isEmpty) {
      return 'Error: experience_id is required.';
    }

    try {
      final updated = await _repository.recordVerdict(
        sentinelId: sentinelId,
        id: experienceId,
        verdict: verdict,
        note: note,
      );
      if (updated == null) {
        return 'Error: Experience "$experienceId" not found. It may belong '
            'to a different Sentinel or have been deleted.';
      }
      if (verdict == ExperienceEntity.verdictRefuted) {
        return 'Experience marked as user-refuted (id: ${updated.id}). '
            'Consider archiving it with experience_learn (action="archive") '
            'so it stops appearing in recall results.';
      }
      return 'Experience marked as user-confirmed (id: ${updated.id}).';
    } catch (e) {
      return 'Error recording verdict: $e';
    }
  }
}
