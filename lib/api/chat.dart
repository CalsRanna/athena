import 'dart:async';

import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart' as schema;
import 'package:athena/schema/provider.dart';
import 'package:athena/vendor/openai_dart/client.dart';
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatApi {
  Future<String> connect({
    required Provider provider,
    required schema.Model model,
  }) async {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var message = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('Hi'),
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: [message],
    );
    try {
      var response = await client.createChatCompletion(request: request);
      if (response.choices.isEmpty) return 'The response has no choices';
      return 'The connection is successful';
    } catch (error) {
      return error.toString();
    }
  }

  Stream<OverrodeChatCompletionStreamResponseDelta> getCompletion({
    required List<Message> messages,
    required Provider provider,
    required schema.Model model,
  }) async* {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OverrodeOpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
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
    var response = client.createOverrodeChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.response.choices.isEmpty) continue;
      var content = chunk.response.choices.first.delta.content ?? '';
      var rawDelta = chunk.rawJson['choices'][0]['delta'];
      var reasoningContent = rawDelta['reasoning_content']; // DeepSeek
      reasoningContent ??= rawDelta['reasoning']; // OpenRouter
      yield OverrodeChatCompletionStreamResponseDelta(
        content: content,
        reasoningContent: reasoningContent,
      );
    }
  }

  Stream<String> getTitle(
    String value, {
    required Provider provider,
    required schema.Model model,
  }) async* {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    const String prompt = '你是一名擅长会话的助理，你需要将用户的会话总结为 10 个字以内的'
        '标题，标题语言与用户的首要语言一致，不要使用标点符号和其他特殊符号。';
    var wrappedMessages = [
      ChatCompletionMessage.system(content: prompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(value),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: wrappedMessages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta.content ?? '';
    }
  }
}
