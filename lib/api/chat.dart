import 'dart:async';

import 'package:athena/schema/chat.dart';
import 'package:athena/util/proxy.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatApi {
  Future<String> connect(String model) async {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: ProxyConfig.instance.key,
      baseUrl: ProxyConfig.instance.url,
      headers: headers,
    );
    var message = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('Hi'),
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: [message],
    );
    try {
      var response = await client.createChatCompletion(request: request);
      if (response.choices.isEmpty) return 'Failed';
      return 'Succeed';
    } catch (error) {
      return 'Failed';
    }
  }

  Stream<String> getCompletion({
    required List<Message> messages,
    String model = 'gpt-4o',
  }) async* {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: ProxyConfig.instance.key,
      baseUrl: ProxyConfig.instance.url,
      headers: headers,
    );
    var wrappedMessages = messages.map((message) {
      if (message.role == 'system') {
        return ChatCompletionMessage.system(content: message.content);
      } else {
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message.content),
        );
      }
    }).toList();
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: wrappedMessages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final event in response) {
      if (event.choices.isEmpty) continue;
      yield event.choices.first.delta.content ?? '';
    }
  }

  Stream<String> getTitle(String value, {required String model}) async* {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: ProxyConfig.instance.key,
      baseUrl: ProxyConfig.instance.url,
      headers: headers,
    );
    const String prompt = '请用最简短的语言总结出「」中内容的主题。不要解释、不要标点符号、'
        '不要语气助词、不要多余文本、长度不得大于10。只需要告诉我你总结的内容，不需要任何其他文'
        '本。并自己判断是否使用英语总结更准确。如果是的话，就使用英语。';
    var wrappedMessages = [
      ChatCompletionMessage.system(content: prompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(value),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: wrappedMessages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final event in response) {
      yield event.choices.first.delta.content ?? '';
    }
  }
}
