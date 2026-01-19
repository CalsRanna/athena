/// 增强版 Delta，支持 reasoning 字段（流式响应中使用）
class EnhancedDelta {
  final String? role;
  final String? content;
  final String? reasoningContent;

  const EnhancedDelta({this.role, this.content, this.reasoningContent});

  factory EnhancedDelta.fromJson(Map<String, dynamic> json) {
    return EnhancedDelta(
      role: json['role'] as String?,
      content: json['content'] as String?,
      // 支持两种字段名: reasoning_content (OpenAI) 和 reasoning (Google Gemini)
      reasoningContent:
          json['reasoning_content'] as String? ?? json['reasoning'] as String?,
    );
  }
}

/// 增强版 Choice（流式响应中使用）
class EnhancedChoice {
  final int index;
  final EnhancedDelta delta;
  final String? finishReason;

  const EnhancedChoice({
    required this.index,
    required this.delta,
    this.finishReason,
  });

  factory EnhancedChoice.fromJson(Map<String, dynamic> json) {
    return EnhancedChoice(
      index: json['index'] as int? ?? 0,
      delta: EnhancedDelta.fromJson(
        json['delta'] as Map<String, dynamic>? ?? {},
      ),
      finishReason: json['finish_reason'] as String?,
    );
  }
}

/// 增强版流式响应
class EnhancedStreamResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<EnhancedChoice> choices;

  const EnhancedStreamResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
  });

  factory EnhancedStreamResponse.fromJson(Map<String, dynamic> json) {
    return EnhancedStreamResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? '',
      created: json['created'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      choices:
          (json['choices'] as List<dynamic>?)
              ?.map((e) => EnhancedChoice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 增强版 Message（非流式响应中使用）
class EnhancedMessage {
  final String role;
  final String content;
  final String? reasoningContent;

  const EnhancedMessage({
    required this.role,
    required this.content,
    this.reasoningContent,
  });

  factory EnhancedMessage.fromJson(Map<String, dynamic> json) {
    return EnhancedMessage(
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      // 支持两种字段名: reasoning_content (OpenAI) 和 reasoning (Google Gemini)
      reasoningContent:
          json['reasoning_content'] as String? ?? json['reasoning'] as String?,
    );
  }
}

/// 增强版 Choice（非流式响应中使用）
class EnhancedNonStreamChoice {
  final int index;
  final EnhancedMessage message;
  final String? finishReason;

  const EnhancedNonStreamChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  factory EnhancedNonStreamChoice.fromJson(Map<String, dynamic> json) {
    return EnhancedNonStreamChoice(
      index: json['index'] as int? ?? 0,
      message: EnhancedMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
      finishReason: json['finish_reason'] as String?,
    );
  }
}

/// 增强版非流式响应
class EnhancedResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<EnhancedNonStreamChoice> choices;

  const EnhancedResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
  });

  factory EnhancedResponse.fromJson(Map<String, dynamic> json) {
    return EnhancedResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? '',
      created: json['created'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      choices:
          (json['choices'] as List<dynamic>?)
              ?.map(
                (e) =>
                    EnhancedNonStreamChoice.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  /// 获取第一条消息的内容
  String? get firstContent => choices.firstOrNull?.message.content;

  /// 获取第一条消息的推理内容
  String? get firstReasoningContent =>
      choices.firstOrNull?.message.reasoningContent;
}
