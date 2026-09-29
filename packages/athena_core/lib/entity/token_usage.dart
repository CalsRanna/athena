/// 单次推理调用的 token 使用统计。
///
/// 由 [AgentEvent.usage] 事件携带，每轮迭代结束（流式响应收到 usage 时）上报。
/// 包含可选的推理 token 明细（部分模型如 o1 / DeepSeek R1 会返回）与
/// prompt 缓存命中 token 数（部分/provider 返回 prompt_tokens_details.cached_tokens）。
class TokenUsage {
  final int promptTokens;
  final int? completionTokens;
  final int totalTokens;
  final int? reasoningTokens;
  final int? cachedTokens;
  final int? cacheCreationTokens;

  /// Observed time from the first to the last output chunk of this response.
  /// Null when fewer than two output chunks were received.
  final Duration? outputDuration;

  const TokenUsage({
    required this.promptTokens,
    this.completionTokens,
    required this.totalTokens,
    this.reasoningTokens,
    this.cachedTokens,
    this.cacheCreationTokens,
    this.outputDuration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenUsage &&
          runtimeType == other.runtimeType &&
          promptTokens == other.promptTokens &&
          completionTokens == other.completionTokens &&
          totalTokens == other.totalTokens &&
          reasoningTokens == other.reasoningTokens &&
          cachedTokens == other.cachedTokens &&
          cacheCreationTokens == other.cacheCreationTokens &&
          outputDuration == other.outputDuration;

  @override
  int get hashCode => Object.hash(
    promptTokens,
    completionTokens,
    totalTokens,
    reasoningTokens,
    cachedTokens,
    cacheCreationTokens,
    outputDuration,
  );

  @override
  String toString() =>
      'TokenUsage(prompt: $promptTokens, completion: $completionTokens, '
      'total: $totalTokens, reasoning: $reasoningTokens, '
      'cached: $cachedTokens, cacheCreated: $cacheCreationTokens)';
}
