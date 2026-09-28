import 'package:openai_dart/openai_dart.dart';

/// 原生停止原因和用量独立落库，避免公共 finishReason 压平协议语义。
class CompletionDetailsChunk extends ChatStreamEvent {
  final Map<String, dynamic> details;
  const CompletionDetailsChunk(this.details);
}

class DetailedChatCompletion extends ChatCompletion {
  final Map<String, dynamic> details;
  const DetailedChatCompletion({
    required this.details,
    super.id,
    required super.object,
    super.created,
    required super.model,
    required super.choices,
    super.usage,
    super.systemFingerprint,
    super.serviceTier,
    super.moderation,
    super.provider,
  });

  @override
  String? get text {
    final message = choices.firstOrNull?.message;
    final content = message?.content;
    return content == null || content.isEmpty
        ? message?.refusal ?? content
        : content;
  }
}

/// OpenAI 的用量类型没有缓存写入字段；保留明细供协调层消费。
class CacheUsage extends Usage {
  final int cacheCreationTokens;
  const CacheUsage({
    required this.cacheCreationTokens,
    required super.promptTokens,
    super.completionTokens,
    required super.totalTokens,
    super.promptTokensDetails,
    super.completionTokensDetails,
  });
}

/// 适配器只能接受已映射的参数，新增 SDK 字段也不能静默丢弃。
void checkRequestFields(
  ChatCompletionCreateRequest request,
  String protocol,
  Set<String> supported,
) {
  final unsupported = request.toJson().keys.toSet().difference(supported);
  if (unsupported.isNotEmpty) {
    throw UnsupportedError(
      '$protocol does not support: ${unsupported.join(', ')}',
    );
  }
  if (request.maxTokens != null &&
      request.maxCompletionTokens != null &&
      request.maxTokens != request.maxCompletionTokens) {
    throw ArgumentError('max_tokens and max_completion_tokens conflict');
  }
}
