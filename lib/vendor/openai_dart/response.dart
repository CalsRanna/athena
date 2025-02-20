import 'package:openai_dart/openai_dart.dart';

class OverrodeCreateChatCompletionStreamResponse {
  final Map<String, dynamic> rawJson;
  final CreateChatCompletionStreamResponse response;

  OverrodeCreateChatCompletionStreamResponse({
    required this.rawJson,
    required this.response,
  });
}
