import 'dart:async';
import 'dart:convert';

import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart' as schema;
import 'package:athena/schema/provider.dart';
import 'package:athena/vendor/openai_dart/client.dart';
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatApi {
  Future<Map<String, dynamic>> checkNeedSearchFromInternet(
    String message, {
    required Provider provider,
    required schema.Model model,
  }) async {
    var headers = {'HTTP-Referer': 'athena.cals.xyz', 'X-Title': 'Athena'};
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    const String prompt = '''作为搜索需求分析专家，请按以下步骤处理用户输入：
1. 判断是否需要联网搜索的标准：
   - 需要实时/最新数据（时效性<1年）
   - 需要特定事实核查
   - 涉及专业领域知识（如法律/医学）
   - 需要扩展外部资源
   - 包含模糊/多义关键词

2. 关键词优化流程：
   a) 分词后去除停用词
   b) 保留名词/专业术语
   c) 合并同义词（如"AI"和"人工智能"）
   d) 按搜索优先级排序
   e) 限制最多5个关键词

3. 输出要求：
   - 严格使用JSON格式
   - need_search值为布尔类型
   - keywords为数组格式
   - 返回内容不能包裹在markdown语法中
   - 示例：{"need_search": true, "keywords": ["量子计算", "应用场景"]}

4. 特殊处理：
   - 当用户询问天气/股价等实时数据时自动触发
   - 排除简单计算/常识问题
   - 适配多语言搜索场景''';
    var wrappedMessages = [
      ChatCompletionMessage.system(content: prompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(message),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: wrappedMessages,
    );
    var response = await client.createChatCompletion(request: request);
    var content = response.choices.first.message.content;
    print(content);
    return jsonDecode(content ?? '');
  }

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
