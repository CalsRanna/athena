import 'package:athena_core/entity/compaction_step.dart';

String compactionStatus(CompactionStep step, {required bool isLive}) {
  if (!step.isTerminal && !isLive) return '压缩已中断';
  return switch (step.phase) {
    CompactionPhase.triggered => '准备压缩',
    CompactionPhase.summarizing => '正在压缩上下文…',
    CompactionPhase.persisting => '正在保存摘要…',
    CompactionPhase.completed => '压缩完成',
    CompactionPhase.failed => '压缩失败',
    CompactionPhase.cancelled => '压缩已取消',
  };
}

String compactionTokenChange(CompactionStep step) => step.afterTokens == null
    ? '约 ${step.beforeTokens} tokens'
    : '约 ${step.beforeTokens} → ${step.afterTokens} tokens';

String compactionDetails(CompactionStep step) => [
  '覆盖 ${step.messageCount} 条消息',
  compactionTokenChange(step),
  if (step.finishedAt != null)
    '耗时 ${(step.finishedAt!.difference(step.startedAt).inMilliseconds / 1000).toStringAsFixed(1)} 秒',
  if (step.error != null) step.error!,
  if (step.summary.isNotEmpty) '\n${step.summary}',
].join('\n');
