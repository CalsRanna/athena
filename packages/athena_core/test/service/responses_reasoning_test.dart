import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/responses_adapter.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/responses_fixture.dart';

void main() {
  final provider = responsesProvider();
  const model = 'test-reasoner';

  ResponsesAssistantMessage assistant() =>
      responseToChatCompletion(
            Response.fromJson(reasoningResponse()),
            provider: provider,
            model: model,
          ).choices.single.message
          as ResponsesAssistantMessage;

  ChatCompletionCreateRequest request(
    List<ChatMessage> messages, {
    String modelId = model,
  }) => ChatCompletionCreateRequest(
    model: modelId,
    messages: messages,
    reasoningEffort: ReasoningEffort.high,
  );

  test('请求开启摘要与无状态推理密文；none/非推理请求不强行启用摘要', () {
    final body = toResponseRequest(request([ChatMessage.user('hi')])).toJson();
    expect(body['reasoning'], {'effort': 'high', 'summary': 'auto'});
    expect(body['store'], isFalse);
    expect(body['include'], contains('reasoning.encrypted_content'));
    for (final effort in [null, ReasoningEffort.none]) {
      final converted = toResponseRequest(
        ChatCompletionCreateRequest(
          model: model,
          messages: [ChatMessage.user('hi')],
          reasoningEffort: effort,
        ),
      );
      expect(converted.reasoning?.summary, isNull);
    }
  });

  test('摘要增量无需等待 done 或响应结束即可显示', () async {
    final chunk = await normalizeResponsesStream(
      Stream.value(
        const ReasoningSummaryTextDeltaEvent(
          outputIndex: 0,
          summaryIndex: 0,
          delta: '正在分析',
        ),
      ),
    ).first;
    expect(chunk.firstChoice!.delta.reasoningContent, '正在分析');
  });

  test('摘要 delta/done/完整 item/终态只显示一次，统一累积到 reasoningContent', () async {
    final chunks = await normalizeResponsesStream(
      Stream.fromIterable(
        reasoningEvents(reasoningResponse()).map(ResponseStreamEvent.fromJson),
      ),
      provider: provider,
      model: model,
    ).toList();
    final accumulator = ChatStreamAccumulator();
    chunks.forEach(accumulator.add);
    expect(accumulator.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(accumulator.reasoning, isEmpty);
    expect(accumulator.content, '准备执行。');
    expect(accumulator.toolCalls.map((c) => c.id), ['call_1_0', 'call_1_1']);
    expect(accumulator.usage!.completionTokensDetails!.reasoningTokens, 25);
    final state = chunks.whereType<ResponsesStateChunk>().single.state;
    expect(state.output.first['encrypted_content'], 'opaque-cipher-1');
    expect(
      state.matchesMessage(
        accumulator.toChatCompletion().choices.single.message,
      ),
      isTrue,
    );
  });

  test('只在终态返回摘要时仍显示；非流式也保留摘要、工具与原生输出', () async {
    final response = Response.fromJson(reasoningResponse());
    final accumulator = ChatStreamAccumulator();
    await for (final chunk in normalizeResponsesStream(
      Stream.value(
        ResponseStreamEvent.fromJson({
          'type': 'response.completed',
          'response': response.toJson(),
        }),
      ),
    )) {
      accumulator.add(chunk);
    }
    final message = assistant();
    expect(message.reasoningContent, accumulator.reasoningContent);
    expect(message.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(message.toolCalls, hasLength(2));
    expect(
      message.responsesState!.output,
      response.output.map((i) => i.toJson()).toList(),
    );
  });

  test('同端点同模型原样回传完整 output，保留 id、密文、phase 和工具顺序', () {
    final message = assistant();
    final input =
        toResponseRequest(
              request([
                ChatMessage.user('hi'),
                message,
                for (final call in message.toolCalls!)
                  ChatMessage.tool(toolCallId: call.id, content: 'ok'),
              ]),
              provider: provider,
            ).input.toJson()
            as List;
    expect(input.sublist(1, 5), message.responsesState!.output);
    expect(input[5], containsPair('call_id', 'call_1_0'));
    expect(input[6], containsPair('call_id', 'call_1_1'));
    expect(input[2]['phase'], 'commentary');
    expect(message.responsesState!.encode(), isNot(contains(provider.apiKey)));
  });

  test('换供应商/端点/模型、编辑消息或过滤调用后不回传旧原生状态', () {
    final message = assistant();
    final state = message.responsesState!;
    for (final other in [
      provider.copyWith(id: 2),
      provider.copyWith(baseUrl: 'https://other.test/v1'),
      provider.copyWith(apiFormat: ApiFormat.chatCompletions),
    ]) {
      expect(state.matches(other, model, message), isFalse);
      final body = toResponseRequest(
        request([message]),
        provider: other,
      ).toJson();
      expect(jsonEncode(body), isNot(contains('opaque-cipher')));
    }
    expect(
      state.matches(
        provider.copyWith(baseUrl: '${provider.baseUrl}/'),
        model,
        message,
      ),
      isTrue,
    );
    for (final changed in [
      ResponsesAssistantMessage(
        content: 'edited',
        toolCalls: message.toolCalls,
        responsesState: state,
      ),
      ResponsesAssistantMessage(
        content: message.content,
        toolCalls: [message.toolCalls!.first],
        responsesState: state,
      ),
    ]) {
      final input = toResponseRequest(
        request([changed]),
        provider: provider,
      ).input.toJson();
      expect(jsonEncode(input), isNot(contains('opaque-cipher')));
    }
    expect(
      jsonEncode(
        toResponseRequest(
          request([message], modelId: 'other'),
          provider: provider,
        ).toJson(),
      ),
      isNot(contains('opaque-cipher')),
    );
    expect(
      jsonEncode(message.toJson()),
      isNot(contains('opaque-cipher')),
      reason: '其他协议和压缩摘要只读取公共消息，不能泄漏密文',
    );
  });

  test('截断、流提前结束与取消异常都不发布可复用状态', () async {
    final incomplete = await normalizeResponsesStream(
      Stream.fromIterable(
        reasoningEvents(
          reasoningResponse(status: 'incomplete'),
        ).map(ResponseStreamEvent.fromJson),
      ),
      provider: provider,
      model: model,
    ).toList();
    expect(incomplete.whereType<ResponsesStateChunk>(), isEmpty);
    expect(incomplete.last.firstChoice!.finishReason, FinishReason.length);
    final events = reasoningEvents(reasoningResponse())..removeLast();
    final partial = <ChatStreamEvent>[];
    await expectLater(normalizeResponsesStream(
      Stream.fromIterable(events.map(ResponseStreamEvent.fromJson)),
      provider: provider,
      model: model,
    ).forEach(partial.add), throwsStateError);
    expect(partial.whereType<ResponsesStateChunk>(), isEmpty);
    final seen = <ChatStreamEvent>[];
    Stream<ResponseStreamEvent> aborted() async* {
      yield* Stream.fromIterable(events.map(ResponseStreamEvent.fromJson));
      throw StateError('cancelled');
    }

    await expectLater(
      normalizeResponsesStream(
        aborted(),
        provider: provider,
        model: model,
      ).forEach(seen.add),
      throwsStateError,
    );
    expect(seen.whereType<ResponsesStateChunk>(), isEmpty);
  });

  test('上下文预算计入隐藏推理用量，不按密文长度计费', () {
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
  });

  test('临时 JSONL 重载后恢复完整状态，旧记录和损坏状态仍可读取', () async {
    final tmp = await Directory.systemTemp.createTemp('athena_responses_');
    addTearDown(() => tmp.delete(recursive: true));
    final storage = FileStorage(root: tmp);
    await storage.load();
    final chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 'test',
        modelId: 1,
        sentinelId: ChatEntity.noSentinelId,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final native = assistant();
    final record = MessageEntity(
      chatId: chatId,
      role: 'assistant',
      content: native.content!,
      reasoningContent: native.reasoningContent!,
      responsesState: native.responsesState!.encode(),
      toolCalls: jsonEncode(
        native.toolCalls!
            .map(
              (call) => {
                'id': call.id,
                'name': call.function.name,
                'arguments': call.function.arguments,
              },
            )
            .toList(),
      ),
      toolResults: jsonEncode(
        native.toolCalls!
            .map((call) => {'id': call.id, 'result': 'ok'})
            .toList(),
      ),
    );
    await storage.sessionRepository.storeMessage(record);
    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = (await reopened.sessionRepository.getMessagesByChatId(
      chatId,
    )).single;
    final converter = ChatMessageConverter(
      messageRepository: reopened.sessionRepository,
    );
    final messages = await converter.convertMessage(
      saved,
      includeReasoning: false,
    );
    final input =
        toResponseRequest(request(messages), provider: provider).input.toJson()
            as List;
    expect(
      input.take(4).toList(),
      native.responsesState!.output,
      reason: '即使隐藏可见摘要，也不能丢掉原生推理状态',
    );
    final filtered = await converter.convertMessage(
      saved.copyWith(
        toolResults: jsonEncode([
          {'id': 'call_1_0', 'result': 'ok'},
        ]),
      ),
    );
    expect(
      jsonEncode(
        toResponseRequest(request(filtered), provider: provider).input.toJson(),
      ),
      isNot(contains('opaque-cipher')),
    );
    for (final value in ['', '{bad json', '{"version":999}']) {
      final restored = await converter.convertMessage(
        saved.copyWith(responsesState: value),
      );
      expect(
        (restored.first as ResponsesAssistantMessage).responsesState,
        isNull,
      );
      expect(restored, hasLength(3));
    }
    expect(
      MessageEntity.fromJson({
        'chat_id': chatId,
        'role': 'assistant',
        'content': 'old',
      }).responsesState,
      isEmpty,
    );
  });
}
