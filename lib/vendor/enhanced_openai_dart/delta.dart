class EnhancedChatCompletionStreamResponseDelta {
  final String content;
  final String? reasoningContent;

  EnhancedChatCompletionStreamResponseDelta({
    required this.content,
    this.reasoningContent,
  });
}
