import 'dart:convert';

import 'package:athena/preset/prompt.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart' as schema;
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:openai_dart/openai_dart.dart';

class SentinelApi {
  Future<Sentinel> generate(
    String prompt, {
    required Provider provider,
    required schema.Model model,
  }) async {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var system = PresetPrompt.metadataGeneration;
    var messages = [
      Message.fromJson({'role': 'system', 'content': system}),
      Message.fromJson({'role': 'user', 'content': prompt}),
    ];
    var wrappedMessages = messages.map((message) {
      if (message.role == 'system') {
        return ChatCompletionMessage.system(content: message.content);
      } else if (message.role == 'assistant') {
        return ChatCompletionMessage.assistant(content: message.content);
      } else {
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message.content),
        );
      }
    }).toList();
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: wrappedMessages,
    );
    var response = await client.createChatCompletion(request: request);
    final content = response.choices.first.message.content;
    final formatted = jsonDecode(
      content.toString().replaceAll('```json', '').replaceAll('```', ''),
    );
    return Sentinel()
      ..name = formatted['name']
      ..description = formatted['description']
      ..tags = List<String>.from(formatted['tags'])
      ..avatar = formatted['avatar'];
  }
}
