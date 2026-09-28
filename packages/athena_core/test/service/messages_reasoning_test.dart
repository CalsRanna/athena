import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/messages_adapter.dart';
import 'package:athena_core/service/messages_state.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/messages_fixture.dart';

void main() {
  final provider = messagesProvider();
  const model = 'claude-sonnet-4-6';
  ChatCompletionCreateRequest request({
    String modelId = model,
    ReasoningEffort? effort = ReasoningEffort.high,
    List<ChatMessage>? messages,
  }) => ChatCompletionCreateRequest(
    model: modelId,
    messages: messages ?? [ChatMessage.user('hi')],
    reasoningEffort: effort,
    temperature: 0.5,
  );
  final native = toMessageRequest(request(), provider: provider);
  MessagesAssistantMessage assistant({Map<String, dynamic>? response}) =>
      messageToChatCompletion(
            anthropic.Message.fromJson(response ?? thinkingMessage()),
            provider: provider,
            request: native,
          ).choices.single.message
          as MessagesAssistantMessage;
  List<ChatMessage> history(MessagesAssistantMessage message) => [
    ChatMessage.user('hi'),
    message,
    for (final call in message.toolCalls ?? <ToolCall>[])
      ChatMessage.tool(toolCallId: call.id, content: 'done'),
  ];
  List<dynamic> assistantBlocks(anthropic.MessageCreateRequest request) =>
      (request.toJson()['messages'] as List)[1]['content'] as List;

  test('新 Claude 使用 adaptive + effort，并移除不兼容的温度', () {
    for (final model in [
      'claude-sonnet-4-6',
      'anthropic/claude-opus-4.6',
      'claude-opus-4-7',
      'claude-opus-5-5',
      'claude-sonnet-5',
      'claude-mythos-preview',
      'claude-fable-5-1',
    ]) {
      for (final effort in [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ]) {
        final body = toMessageRequest(
          request(modelId: model, effort: effort),
        ).toJson();
        expect(body['thinking'], {
          'type': 'adaptive',
          'display': 'summarized',
        }, reason: model);
        expect(body['output_config'], {'effort': effort.value});
        expect(body, isNot(contains('temperature')));
      }
    }
    expect(
      toMessageRequest(
        request(effort: ReasoningEffort.xhigh),
      ).toJson()['output_config'],
      {'effort': 'max'},
    );
    expect(
      toMessageRequest(
        request(modelId: 'claude-opus-4-7', effort: ReasoningEffort.xhigh),
      ).toJson()['output_config'],
      {'effort': 'xhigh'},
    );
  });

  test('旧 Claude/兼容模型用 budget，受输出余量约束并留出回答空间', () {
    for (final model in [
      'claude-3-7-sonnet-20250219',
      'claude-sonnet-4-5',
      'claude-opus-4-5',
      'claude-haiku-4-5',
      'compatible-reasoner',
    ]) {
      final budgets = <int>[];
      for (final effort in [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ]) {
        final body = toMessageRequest(
          request(modelId: model, effort: effort),
          maxTokens: 16000,
        ).toJson();
        expect(body['thinking']['type'], 'enabled');
        budgets.add(body['thinking']['budget_tokens'] as int);
        expect(body, isNot(contains('output_config')));
        expect(body, isNot(contains('temperature')));
      }
      expect(budgets, [2048, 4096, 8192]);
    }
    final capped = toMessageRequest(
      request(modelId: 'claude-sonnet-4-5'),
      maxTokens: 5000,
    ).toJson();
    expect(capped['thinking']['budget_tokens'], 3976);
    expect(capped['max_tokens'], 5000);
    expect(
      () => toMessageRequest(
        request(modelId: 'claude-sonnet-4-5'),
        maxTokens: 1024,
      ),
      throwsStateError,
    );
  });

  test('none 显式关闭推理；普通请求不注入 thinking；常开模型不伪装关闭成功', () {
    expect(
      toMessageRequest(
        request(effort: ReasoningEffort.none),
      ).toJson()['thinking'],
      {'type': 'disabled'},
    );
    final plain = toMessageRequest(request(effort: null)).toJson();
    expect(plain, isNot(contains('thinking')));
    expect(plain['temperature'], 0.5);
    expect(
      toMessageRequest(
        request(modelId: 'claude-opus-4-7', effort: null),
      ).toJson(),
      isNot(contains('temperature')),
    );
    expect(
      () => toMessageRequest(
        request(modelId: 'claude-opus-5-5', effort: ReasoningEffort.none),
      ),
      throwsUnsupportedError,
    );
  });

  test('流式展示不等签名；完整流保留初始文本、隐藏块、签名和块顺序', () async {
    final early = await normalizeMessagesStream(
      Stream.value(
        anthropic.ContentBlockDeltaEvent.fromJson({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'thinking_delta', 'thinking': '思考中'},
        }),
      ),
    ).single;
    expect(early.firstChoice!.delta.reasoningContent, '思考中');
    final chunks = await normalizeMessagesStream(
      Stream.fromIterable(
        thinkingEvents(
          thinkingMessage(),
          initialText: true,
        ).map(anthropic.MessageStreamEvent.fromJson),
      ),
      provider: provider,
      request: native,
    ).toList();
    final accumulator = ChatStreamAccumulator();
    chunks.forEach(accumulator.add);
    expect(accumulator.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(accumulator.reasoning, isEmpty);
    expect(accumulator.content, '准备执行。');
    expect(accumulator.toolCalls, hasLength(2));
    expect(accumulator.usage!.completionTokensDetails!.reasoningTokens, 25);
    final state = chunks.whereType<MessagesStateChunk>().single.state;
    expect(state.content, thinkingMessage()['content']);
    expect(
      state.matchesMessage(
        accumulator.toChatCompletion().choices.single.message,
      ),
      isTrue,
    );
    expect(chunks.last, isA<MessagesStateChunk>());
  });

  test('非流式保留推理、工具及原生状态；工具续接回传完整原始块', () {
    final message = assistant();
    expect(message.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(message.toolCalls, hasLength(2));
    expect(
      assistantBlocks(
        toMessageRequest(
          request(messages: history(message)),
          provider: provider,
        ),
      ),
      thinkingMessage()['content'],
    );
    expect(jsonEncode(message.toJson()), isNot(contains('signature_')));
    expect(jsonEncode(message.toJson()), isNot(contains('redacted_')));
  });

  test('来源、消息、工具或前缀改变后不回传旧签名', () {
    final message = assistant();
    void noState(
      List<ChatMessage> messages, {
      String modelId = model,
      bool otherProvider = false,
    }) {
      final body = toMessageRequest(
        request(modelId: modelId, messages: messages),
        provider: otherProvider
            ? provider.copyWith(baseUrl: 'https://other.example')
            : provider,
      ).toJson();
      expect(jsonEncode(body), isNot(contains('signature_')));
      expect(jsonEncode(body), isNot(contains('redacted_')));
    }

    noState(history(message), modelId: 'claude-opus-4-6');
    noState(history(message), otherProvider: true);
    noState([ChatMessage.user('edited'), ...history(message).skip(1)]);
    noState([ChatMessage.system('new system'), ...history(message)]);
    noState(
      history(
        MessagesAssistantMessage(
          content: 'edited',
          toolCalls: message.toolCalls,
          messagesState: message.messagesState,
        ),
      ),
    );
    noState(
      history(
        MessagesAssistantMessage(
          content: message.content,
          toolCalls: message.toolCalls!.take(1).toList(),
          messagesState: message.messagesState,
        ),
      ),
    );
    expect(
      message.messagesState!.matches(
        provider.copyWith(apiFormat: ApiFormat.responses),
        model,
        message,
        MessagesState.hashPrefix(native),
      ),
      isFalse,
    );
  });

  test('手动 thinking 在工具循环内保持预算，输出余量不足时明确失败', () {
    final manual = toMessageRequest(
      request(modelId: 'claude-sonnet-4-5'),
      maxTokens: 16000,
      provider: provider,
    );
    final message =
        messageToChatCompletion(
              anthropic.Message.fromJson(thinkingMessage()),
              provider: provider,
              request: manual,
            ).choices.single.message
            as MessagesAssistantMessage;
    final next = request(
      modelId: 'claude-sonnet-4-5',
      effort: ReasoningEffort.low,
      messages: history(message),
    );
    final body = toMessageRequest(
      next,
      maxTokens: 12000,
      provider: provider,
    ).toJson();
    expect(body['thinking'], manual.thinking!.toJson());
    expect(
      () => toMessageRequest(next, maxTokens: 8192, provider: provider),
      throwsStateError,
    );
  });

  test('断流、截断、错误和缺失签名不发布可复用状态', () async {
    final full = thinkingEvents(thinkingMessage());
    final cases = [
      full.take(full.length - 1).toList(),
      thinkingEvents(thinkingMessage(stop: 'max_tokens')),
      full
          .where(
            (e) =>
                e['delta'] is! Map || e['delta']['type'] != 'signature_delta',
          )
          .toList(),
      [
        ...full.take(5),
        {
          'type': 'error',
          'error': {'type': 'api_error', 'message': 'failed'},
        },
      ],
    ];
    for (final events in cases) {
      final states = <MessagesStateChunk>[];
      try {
        await for (final chunk in normalizeMessagesStream(
          Stream.fromIterable(
            events.map(anthropic.MessageStreamEvent.fromJson),
          ),
          provider: provider,
          request: native,
        )) {
          if (chunk is MessagesStateChunk) states.add(chunk);
        }
      } on StateError {
        // 提前 EOF 或缺签名也必须显式失败。
      } on anthropic.ApiException {
        /* 已收到的展示文字仍可保留。 */
      }
      expect(states, isEmpty);
    }
    expect(
      assistant(response: thinkingMessage(stop: 'max_tokens')).messagesState,
      isNull,
    );
  });

  test('上下文计入真实推理用量，签名不进入普通消息序列化', () {
    final message = assistant();
    final plain = AssistantMessage(
      content: message.content,
      toolCalls: message.toolCalls,
      reasoningContent: message.reasoningContent,
    );
    final budget = ContextBudget(100000);
    expect(
      budget.estimate([message], null) - budget.estimate([plain], null),
      25,
    );
    final noDetails = thinkingMessage();
    (noDetails['usage'] as Map).remove('output_tokens_details');
    expect(
      assistant(response: noDetails).messagesState!.reasoningTokens,
      80,
      reason: '旧端点未报告推理明细时用总输出保守预留',
    );
  });

  test('JSONL 重载完整恢复 thinking，旧记录与损坏状态仍可读取', () async {
    final tmp = await Directory.systemTemp.createTemp('athena_messages_state_');
    addTearDown(() => tmp.delete(recursive: true));
    final storage = FileStorage(root: tmp);
    await storage.load();
    final chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 'test',
        modelId: '1',
        sentinelId: ChatEntity.noSentinelId,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final message = assistant();
    await storage.sessionRepository.storeMessage(
      MessageEntity(
        chatId: chatId,
        role: 'assistant',
        content: message.content!,
        reasoningContent: message.reasoningContent!,
        messagesState: message.messagesState!.encode(),
        toolCalls: jsonEncode([
          for (final c in message.toolCalls!)
            {
              'id': c.id,
              'name': c.function.name,
              'arguments': c.function.arguments,
            },
        ]),
        toolResults: jsonEncode([
          for (final c in message.toolCalls!) {'id': c.id, 'result': 'done'},
        ]),
      ),
    );
    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = (await reopened.sessionRepository.getMessagesByChatId(
      chatId,
    )).single;
    final converter = ChatMessageConverter(
      messageRepository: reopened.sessionRepository,
    );
    final converted = await converter.convertMessage(
      saved,
      includeReasoning: true,
    );
    expect(
      assistantBlocks(
        toMessageRequest(
          request(messages: [ChatMessage.user('hi'), ...converted]),
          provider: provider,
        ),
      ),
      thinkingMessage()['content'],
    );
    for (final value in ['', '{broken', '{"version": 99}']) {
      expect(MessagesState.decode(value), isNull);
      expect(
        await converter.convertMessage(saved.copyWith(messagesState: value)),
        hasLength(3),
      );
    }
    expect(
      MessageEntity.fromJson({
        'chat_id': chatId,
        'role': 'assistant',
      }).messagesState,
      isEmpty,
    );
  });
}
