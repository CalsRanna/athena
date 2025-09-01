import 'package:openai_dart/openai_dart.dart';

class EnhancedCreateChatCompletionStreamResponse {
  final Map<String, dynamic> rawJson;
  final CreateChatCompletionStreamResponse response;

  EnhancedCreateChatCompletionStreamResponse({
    required this.rawJson,
    required this.response,
  });
}
