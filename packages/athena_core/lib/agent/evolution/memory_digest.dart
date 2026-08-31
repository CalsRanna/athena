import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// 记忆摘要注入器。
///
/// 背景：经验内容原本不出现在任何上下文中，`experience_recall` 全靠
/// Agent 自觉触发——Agent 看不到经验内容，无从判断"当前任务与经验相关"，
/// 检索环节在真实行为中近乎缺位。
///
/// 设计：每次 run 开始时把**相关经验的摘要**确定性注入上下文
/// （摘要 ~150 token/run），完整内容仍由 `experience_recall` 按需加载。
/// 这是"token 经济"与"记忆必须在场"的折中——摘要保证 Agent 至少
/// 知道记忆存在，深度内容才依赖自觉。
class MemoryDigest {
  MemoryDigest._();

  /// 每条摘要的最大字符数（截断到词边界）。
  static const int maxLessonChars = 80;

  /// 自动注入的最大条数。
  static const int defaultLimit = 3;

  /// 摘要段落的固定开头（系统提示语气，与 evolution hint 互补）。
  static const String _header =
      'The following are your past experiences that may be relevant to the '
      'current task. Call experience_recall for the full lesson if needed:';

  /// 把经验列表格式化为摘要文本（纯函数，可单测）。
  static String buildDigest(List<ExperienceEntity> experiences) {
    final buffer = StringBuffer(_header);
    buffer.writeln();
    for (final e in experiences) {
      final origin = e.scope == 'shared' ? 'shared' : 'private';
      final date = '${e.createdAt.year}-${_pad(e.createdAt.month)}-${_pad(e.createdAt.day)}';
      final verdict = e.userVerdict == ExperienceEntity.verdictConfirmed
          ? ' [user-confirmed]'
          : e.userVerdict == ExperienceEntity.verdictRefuted
              ? ' [user-refuted]'
              : '';
      buffer.writeln(
          '- [${e.id}] ($origin, $date)$verdict ${_truncate(e.lesson)}');
    }
    return buffer.toString();
  }

  /// 检索当前任务相关的经验并生成摘要消息。
  ///
  /// 无相关经验时返回 null（调用方零成本跳过，不注入空段）。
  static Future<List<ChatMessage>?> messagesFor({
    required ExperienceRepository repository,
    required String query,
    required String sentinelId,
    int limit = defaultLimit,
  }) async {
    final results =
        await repository.searchForSentinel(sentinelId, query.trim());
    if (results.isEmpty) return null;
    if (results.length > limit) {
      // 已按相关度排序，取评分最高的前 limit 条
      results.removeRange(limit, results.length);
    }
    return [ChatMessage.system(buildDigest(results))];
  }

  /// 单行化并按词边界截断（最多 [maxLessonChars] 字符）。
  static String _truncate(String text) {
    var singleLine = text.replaceAll('\n', ' ').trim();
    if (singleLine.length <= maxLessonChars) return singleLine;
    final cut = singleLine.substring(0, maxLessonChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${(lastSpace > 20 ? cut.substring(0, lastSpace) : cut).trim()}…';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
