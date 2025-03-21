import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:athena/model/mcp_tool_call.dart';
import 'package:athena/model/search_decision.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart' as schema;
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/mcp_util.dart';
import 'package:athena/vendor/openai_dart/client.dart';
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatApi {
  Future<String> connect({
    required Provider provider,
    required schema.Model model,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
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
    var response = await client.createChatCompletion(request: request);
    return response.choices.first.message.content ?? '';
  }

  Stream<OverrodeChatCompletionStreamResponseDelta> getCompletion({
    required Chat chat,
    required List<Message> messages,
    required Provider provider,
    required schema.Model model,
    List<ChatCompletionTool>? tools,
    List<Server>? servers,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OverrodeOpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var context = messages.length;
    if (chat.context > 0) {
      context = min(chat.context * 2, messages.length);
    }
    var start = max(0, messages.length - context);
    var contextMessages = messages.sublist(start);
    var wrappedMessages = contextMessages.map((message) {
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
      temperature: chat.temperature,
      tools: tools,
    );
    var response = client.createOverrodeChatCompletionStream(request: request);
    Map<int, McpToolCall> toolCalls = {};
    await for (final chunk in response) {
      if (chunk.response.choices.isEmpty) continue;
      if (chunk.response.choices.first.delta.toolCalls != null) {
        if (chunk.response.choices.first.delta.toolCalls!.isEmpty) continue;
        var toolCallChunk = chunk.response.choices.first.delta.toolCalls!.first;
        if (!toolCalls.containsKey(toolCallChunk.index)) {
          toolCalls[toolCallChunk.index] = McpToolCall();
        }
        toolCalls[toolCallChunk.index]!.process(toolCallChunk);
        continue;
      }
      var content = chunk.response.choices.first.delta.content ?? '';
      var rawDelta = chunk.rawJson['choices'][0]['delta'];
      var reasoningContent = rawDelta['reasoning_content']; // DeepSeek
      reasoningContent ??= rawDelta['reasoning']; // OpenRouter
      yield OverrodeChatCompletionStreamResponseDelta(
        content: content,
        reasoningContent: reasoningContent,
      );
    }
    for (var entry in toolCalls.entries) {
      var toolCall = entry.value;
      yield OverrodeChatCompletionStreamResponseDelta(content: '''
\n
```tool_call
$toolCall
```
''');
      var server = await McpUtil().getServer(toolCall, servers: servers ?? []);
      if (server == null) {
        yield OverrodeChatCompletionStreamResponseDelta(content: '''
\n
```tool_call_error
No server found for tool call
```
''');
      } else {
        var result = await McpUtil().callTool(toolCall, server);
        yield OverrodeChatCompletionStreamResponseDelta(content: '''
\n
```tool_call_result
$result
```
''');
      }
    }
  }

  Future<SearchDecision> getSearchDecision(
    String message, {
    required Provider provider,
    required schema.Model model,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var now = DateTime.now();
    var prompt =
        PresetPrompt.searchDecisionPrompt.replaceAll('{now}', now.toString());
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
    var content = response.choices.first.message.content ?? '';
    content = content.replaceAll('```json', '').replaceAll('```', '');
    try {
      var json = jsonDecode(content);
      return SearchDecision.fromJson(json);
    } catch (error) {
      return SearchDecision();
    }
  }

  Stream<String> getTitle(
    String value, {
    required Provider provider,
    required schema.Model model,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var wrappedMessages = [
      ChatCompletionMessage.system(content: PresetPrompt.namingPrompt),
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
