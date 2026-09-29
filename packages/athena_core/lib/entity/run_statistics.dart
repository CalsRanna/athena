import 'package:athena_core/entity/token_usage.dart';

/// Cumulative output usage and wall-clock timing for one agent run.
class RunStatistics {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? outputTokens;
  final double? outputTokensPerSecond;

  const RunStatistics({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    this.outputTokens,
    this.outputTokensPerSecond,
  });

  RunStatistics copyWith({DateTime? finishedAt}) => RunStatistics(
    id: id,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    outputTokens: outputTokens,
    outputTokensPerSecond: outputTokensPerSecond,
  );

  Duration elapsedAt(DateTime now) => (finishedAt ?? now).difference(startedAt);

  /// Accumulates output usage and samples the latest response's output rate.
  RunStatistics withUsage(TokenUsage usage) {
    final responseTokens = usage.completionTokens;
    if (responseTokens == null) return this;
    final tokens = (outputTokens ?? 0) + responseTokens;
    if (tokens == outputTokens) return this;
    return RunStatistics(
      id: id,
      startedAt: startedAt,
      finishedAt: finishedAt,
      outputTokens: tokens,
      outputTokensPerSecond: _outputRate(responseTokens, usage.outputDuration),
    );
  }

  static double? _outputRate(int tokens, Duration? elapsed) {
    if (elapsed == null || elapsed.inMicroseconds <= 0) return null;
    final microseconds = elapsed.inMicroseconds;
    return tokens * Duration.microsecondsPerSecond / microseconds;
  }

  factory RunStatistics.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['started_at'] as String);
    final finishedAt = json['finished_at'] == null
        ? null
        : DateTime.parse(json['finished_at'] as String);
    final outputTokens = json['output_tokens'] as int?;
    return RunStatistics(
      id: json['id'] as String,
      startedAt: startedAt,
      finishedAt: finishedAt,
      outputTokens: outputTokens,
      // 旧字段是整个 run 的平均速率，不能作为单次 LLM 生成速度展示。
      outputTokensPerSecond: (json['response_output_tokens_per_second'] as num?)
          ?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'started_at': startedAt.toIso8601String(),
    if (finishedAt != null) 'finished_at': finishedAt!.toIso8601String(),
    'output_tokens': outputTokens,
    'response_output_tokens_per_second': outputTokensPerSecond,
  };
}
