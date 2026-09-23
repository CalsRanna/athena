import 'dart:convert';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 只读用的最小仓储：测试只走 [getMessagesByChatId]，写方法不应被调用。
class _FakeMessageRepository implements MessageRepository {
  _FakeMessageRepository(this.messages);

  final List<MessageEntity> messages;

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async => messages
      .where((m) => m.chatId == chatId && (includeCompacted || !m.compacted))
      .toList();

  @override
  Future<MessageEntity?> getMessageById(int id) async =>
      messages.where((m) => m.id == id).firstOrNull;

  @override
  Future<int> getMessagesCount(int chatId) async =>
      messages.where((m) => m.chatId == chatId).length;

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async =>
      messages.where((m) => m.chatId == chatId).lastOrNull;

  @override
  Future<List<int>> getTurnStartIds(int chatId) async => const [];

  @override
  Future<int> storeMessage(MessageEntity message) =>
      throw UnimplementedError('read-only fake');

  @override
  Future<void> updateMessage(MessageEntity message) =>
      throw UnimplementedError('read-only fake');

  @override
  Future<void> deleteMessage(int id) =>
      throw UnimplementedError('read-only fake');

  @override
  Future<void> deleteMessagesByChatId(int chatId) =>
      throw UnimplementedError('read-only fake');

  @override
  Future<void> markAsCompacted(Set<int> ids) =>
      throw UnimplementedError('read-only fake');
}

ChatEntity _chat({int retention = -1}) => ChatEntity(
  id: 1,
  title: 't',
  modelId: 1,
  sentinelId: ChatEntity.noSentinelId,
  retention: retention,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

MessageEntity _message({
  required int id,
  required String role,
  String content = '',
  String reasoningContent = '',
  List<Map<String, dynamic>> toolCalls = const [],
  List<Map<String, dynamic>> toolResults = const [],
}) => MessageEntity(
  id: id,
  chatId: 1,
  role: role,
  content: content,
  reasoningContent: reasoningContent,
  reasoning: reasoningContent.isNotEmpty,
  toolCalls: toolCalls.isEmpty ? '' : jsonEncode(toolCalls),
  toolResults: toolResults.isEmpty ? '' : jsonEncode(toolResults),
);

/// 非法请求的判据：OpenAI 兼容端（DeepSeek/OpenAI）要求 assistant 消息至少
/// 带 content 或 tool_calls 之一，两者皆空即 400
/// （`Invalid assistant message: content or tool_calls must be set`）。
bool _isIllegalAssistant(ChatMessage m) =>
    m is AssistantMessage && m.content == null && m.toolCalls == null;

List<Map<String, dynamic>> _call(String id, String name) => [
  {'id': id, 'name': name, 'arguments': '{}'},
];

List<Map<String, dynamic>> _result(String id, String name) => [
  {'id': id, 'name': name, 'result': 'Error: x', 'modelResult': 'Error: x'},
];

Future<List<ChatMessage>> _build(
  List<MessageEntity> messages, {
  bool includeReasoning = false,
  int retention = -1,
}) => ChatMessageConverter(messageRepository: _FakeMessageRepository(messages))
    .buildMessages(
      chat: _chat(retention: retention),
      sentinel: null,
      includeReasoning: includeReasoning,
    );

void main() {
  group('空 assistant 记录不产生非法请求', () {
    test('进程被强杀后遗留的空迭代占位不进入请求', () async {
      // 硬中断（强杀 / 崩溃 / 断电）时收尾流程没跑，appendAssistantPlaceholder
      // 落下的空消息会永远留在历史里。
      final messages = await _build([
        _message(id: 1, role: 'user', content: '你好'),
        _message(id: 2, role: 'assistant'),
      ]);

      expect(messages.where(_isIllegalAssistant), isEmpty);
      expect(messages, hasLength(1));
      expect(messages.single, isA<UserMessage>());
    });

    test('只思考没输出（content 空、无 tool_calls）的记录同样被丢弃', () async {
      // 思考模式 + 输出被截断：reasoning 有内容、正文为空，落库后同样会让
      // 整个会话卡死；即使调用方要求携带 reasoning 也必须丢弃。
      final messages = await _build([
        _message(id: 1, role: 'user', content: '你好'),
        _message(id: 2, role: 'assistant', reasoningContent: '想了很久'),
      ], includeReasoning: true);

      expect(messages.where(_isIllegalAssistant), isEmpty);
      expect(messages, hasLength(1));
    });

    test('已宣布但全部无结果的 tool_calls 与空正文一并丢弃', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '你好'),
        _message(id: 2, role: 'assistant', toolCalls: _call('c1', 'bash')),
      ]);

      expect(messages.where(_isIllegalAssistant), isEmpty);
      expect(messages, hasLength(1));
    });

    test('空记录不阻止其后历史继续发送', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '第一问'),
        _message(id: 2, role: 'assistant'),
        _message(id: 3, role: 'user', content: '第二问'),
        _message(id: 4, role: 'assistant', content: '答'),
      ]);

      expect(messages.where(_isIllegalAssistant), isEmpty);
      expect(messages, hasLength(3));
    });
  });

  group('回归：正常消息成对发出', () {
    test('纯文本 assistant 保留', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '你好'),
        _message(id: 2, role: 'assistant', content: '你好呀'),
      ]);

      final assistant = messages.singleWhere((m) => m is AssistantMessage);
      expect((assistant as AssistantMessage).content, '你好呀');
    });

    test('tool_calls 与其 tool 消息成对，数量一致', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '查一下'),
        _message(
          id: 2,
          role: 'assistant',
          content: '我来查',
          toolCalls: _call('c1', 'bash'),
          toolResults: _result('c1', 'bash'),
        ),
      ]);

      final assistant =
          messages.singleWhere((m) => m is AssistantMessage)
              as AssistantMessage;
      expect(assistant.content, '我来查');
      expect(assistant.toolCalls, hasLength(1));
      expect(messages.whereType<ToolMessage>(), hasLength(1));
      expect(messages.where(_isIllegalAssistant), isEmpty);
    });

    test('有正文但 tool_calls 全无结果：保留正文、丢掉 tool_calls', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '你好'),
        _message(
          id: 2,
          role: 'assistant',
          content: '我准备调用工具',
          toolCalls: _call('c1', 'bash'),
        ),
      ]);

      final assistant =
          messages.singleWhere((m) => m is AssistantMessage)
              as AssistantMessage;
      expect(assistant.content, '我准备调用工具');
      expect(assistant.toolCalls, isNull);
      expect(messages.whereType<ToolMessage>(), isEmpty);
    });
  });

  group('retention == 0（零上下文）', () {
    test('只发最后一条用户消息', () async {
      final messages = await _build([
        _message(id: 1, role: 'user', content: '第一问'),
        _message(id: 2, role: 'assistant'),
        _message(id: 3, role: 'user', content: '第二问'),
      ], retention: 0);

      expect(messages, hasLength(1));
      expect(messages.single, isA<UserMessage>());
      expect('${(messages.single as UserMessage).content}', contains('第二问'));
    });
  });
}
