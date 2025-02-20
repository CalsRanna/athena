class OverrodeChatCompletionStreamResponseDelta {
  final String content;
  final String? reasoningContent;

  OverrodeChatCompletionStreamResponseDelta({
    required this.content,
    this.reasoningContent,
  });
}
