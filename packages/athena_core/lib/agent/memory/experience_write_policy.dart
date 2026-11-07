/// 主动记录与自动反思共用的长期记忆写入门槛。
abstract final class ExperienceWritePolicy {
  static const minConfidence = 0.9;

  static bool accepts(Map<String, dynamic> args) {
    final reuseReason = args['reuse_reason'];
    final evidence = args['evidence'];
    final confidence = args['confidence'];
    return args['durability'] == 'long_term' &&
        reuseReason is String &&
        reuseReason.trim().isNotEmpty &&
        evidence is String &&
        evidence.trim().isNotEmpty &&
        confidence is num &&
        confidence.isFinite &&
        confidence >= minConfidence &&
        confidence <= 1;
  }

  static String contextWithEvidence(
    String context,
    Map<String, dynamic> args,
  ) => [
    if (context.trim().isNotEmpty) context.trim(),
    '长期复用理由：${(args['reuse_reason'] as String).trim()}',
    '验证依据：${(args['evidence'] as String).trim()}',
  ].join('\n');
}
