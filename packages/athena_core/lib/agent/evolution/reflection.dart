import 'dart:convert';

import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/entity/experience_entity.dart';

/// 失败后的轻量反思策略。
///
/// 只对可归因的失败触发。用户取消、网络异常和单次工具失败不应生成长期经验。
abstract final class ReflectionPolicy {
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
    // 反思通道的程序化调用同样要带必填的调用说明（会作为卡片展示给用户）。
    toolCallDescriptionKey: '沉淀本轮失败的教训',
  };

  static String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return text.substring(start, end + 1);
  }
}

abstract final class ReflectionPrompt {
  static const system =
      '''
分析运行结果，判断其中是否有一条长期有效、可执行的经验，值得提议作为长期记忆。
不要记录暂时的网络或服务提供商故障、用户取消、权限拒绝、秘密、原始文件内容，
或仅与本次任务有关的事实。原始错误信息不是经验。
lesson 不超过 ${ExperienceEntity.maxLessonLength} 个字符，支持性细节放入 context。

只返回一个 JSON 对象，格式为：
{"should_learn":false}
或
{"should_learn":true,"lesson":"具体可执行的经验","context":"适用情境","tags":["标签"],"scope":"self","confidence":0.0}

仅当经验是用户的通用偏好时使用 scope="shared"，其他情况使用 self。
不要包含 Markdown 或额外说明。''';

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
