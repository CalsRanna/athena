import 'package:athena/util/proxy.dart';
import 'package:openai_dart/openai_dart.dart';

class TavernApi {
  Stream<String> getCompletion({
    required List<ChatCompletionMessage> messages,
    required String model,
  }) async* {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: ProxyConfig.instance.key,
      baseUrl: ProxyConfig.instance.url,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: messages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final event in response) {
      if (event.choices.isEmpty) continue;
      yield event.choices.first.delta.content ?? '';
    }
  }

  Stream<String> getTitle({required String model}) async* {
    const String prompt = '你是一个跑团游戏的主持人，请你说一段跑团游戏的开场白。主要目的是引导用户选择他想要的游戏风格。';
    var messages = [
      ChatCompletionMessage.system(content: prompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string('开始'),
      ),
    ];
    var response = getCompletion(messages: messages, model: model);
    await for (final token in response) {
      yield token;
    }
  }
}
