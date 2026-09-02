import 'dart:convert';

import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/entity/experience_entity.dart';

/// 失败后的轻量反思策略。
///
/// 只对可归因的失败触发。用户取消、网络异常和单次工具失败不应生成长期经验。
class ReflectionPolicy {
  ReflectionPolicy._();

  static bool shouldReflect(AgentRunOutcome outcome) {
    if (outcome.termination == AgentRunTermination.maxIterations) {
      // 迭代耗尽但唯一证据只是用户/规则拒绝授权时，不把权限选择包装成
      // “需要学习的失败”。无工具失败证据时仍允许模型判断是否存在循环问题。
      return outcome.toolFailures.isEmpty ||
          outcome.toolFailures.any(
            (failure) => failure.status != ToolResultStatus.blocked,
          );
    }
    if (outcome.termination != AgentRunTermination.completed) return false;

    final failuresByTool = <String, int>{};
    for (final failure in outcome.toolFailures) {
      if (failure.status == ToolResultStatus.blocked) continue;
      failuresByTool.update(
        failure.toolName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return failuresByTool.values.any((count) => count >= 2);
  }
}

/// Reflection 模型输出的候选经验。
class ReflectionProposal {
  final String lesson;
  final String context;
  final String tags;
  final String scope;
  final double confidence;

  const ReflectionProposal({
    required this.lesson,
    required this.context,
    required this.tags,
    required this.scope,
    required this.confidence,
  });

  /// 低置信度、无教训或显式 should_learn=false 时不产生写入提案。
  static ReflectionProposal? tryParse(String text) {
    final jsonText = _extractJsonObject(text);
    if (jsonText == null) return null;

    try {
      final json = jsonDecode(jsonText) as Map<String, dynamic>;
      if (json['should_learn'] != true) return null;
      final lesson = (json['lesson'] as String? ?? '').trim();
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
      if (lesson.isEmpty ||
          lesson.length > ExperienceEntity.maxLessonLength ||
          confidence < 0.7) {
        return null;
      }

      final rawTags = json['tags'];
      final tags = rawTags is List
          ? rawTags
                .map((tag) => tag.toString().trim())
                .where((tag) => tag.isNotEmpty)
                .join(', ')
          : (rawTags as String? ?? '').trim();
      final scope = json['scope'] == 'shared' ? 'shared' : 'self';
      return ReflectionProposal(
        lesson: lesson,
        context: (json['context'] as String? ?? '').trim(),
        tags: tags,
        scope: scope,
        confidence: confidence,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toToolArguments() => {
    'action': 'create',
    'lesson': lesson,
    if (context.isNotEmpty) 'context': context,
    if (tags.isNotEmpty) 'tags': tags,
    'scope': scope,
  };

  static String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return text.substring(start, end + 1);
  }
}

class ReflectionPrompt {
  ReflectionPrompt._();

  static const system =
      '''
Analyze the run outcome and decide whether it contains one durable, actionable
lesson worth proposing as long-term memory. Do not record transient network or
provider failures, user cancellation, permission denial, secrets, raw file
contents, or task-specific facts. A raw error message is not a lesson.
Keep lesson within ${ExperienceEntity.maxLessonLength} characters and put
supporting detail in context.

Return exactly one JSON object with:
{"should_learn":false}
or
{"should_learn":true,"lesson":"specific actionable lesson","context":"when it applies","tags":["tag"],"scope":"self","confidence":0.0}

Use scope="shared" only for a universal user preference. Otherwise use self.
Do not include markdown or commentary.''';

  static String input({
    required AgentRunOutcome outcome,
    required String task,
  }) {
    final failures = outcome.toolFailures
        .take(8)
        .map(
          (failure) => {
            'tool': failure.toolName,
            'status': failure.status.name,
            'message': _truncate(failure.message, 600),
          },
        )
        .toList();
    return jsonEncode({
      'task': _truncate(task, 2000),
      'termination': outcome.termination.name,
      'iterations': outcome.iterations,
      'tool_failures': failures,
    });
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max)}…';
}
