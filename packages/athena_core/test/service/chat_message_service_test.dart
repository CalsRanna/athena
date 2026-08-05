import 'dart:convert';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:test/test.dart';
import 'package:openai_dart/openai_dart.dart';

/// A fake [MessageRepository] that returns a fixed list of [MessageEntity],
/// allowing [ChatMessageService.buildMessages] to be driven deterministically
/// without a database.
class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository(this._messages);

  final List<MessageEntity> _messages;

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    if (includeCompacted) return _messages;
    return _messages.where((m) => !m.compacted).toList();
  }

  @override
  Future<void> markAsCompacted(Set<int> ids) async {}

  @override
  Future<MessageEntity?> getMessageById(int id) async => null;

  @override
  Future<int> storeMessage(MessageEntity message) async => 0;

  @override
  Future<void> updateMessage(MessageEntity message) async {}

  @override
  Future<void> deleteMessage(int id) async {}

  @override
  Future<void> deleteMessagesByChatId(int chatId) async {}

  @override
  Future<int> getMessagesCount(int chatId) async => 0;

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async => null;
}

ChatEntity _chat({required int retention}) => ChatEntity(
      id: 1,
      title: 'test',
      modelId: 1,
      sentinelId: 1,
      retention: retention,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

MessageEntity _user(String content) =>
    MessageEntity(chatId: 1, role: 'user', content: content);

MessageEntity _assistantText(String content) =>
    MessageEntity(chatId: 1, role: 'assistant', content: content);

/// An assistant entity that carries BOTH tool_calls and their matching
/// tool_results, mirroring how a completed tool round-trip is persisted.
MessageEntity _assistantWithTools({
  String content = '',
  required List<String> callIds,
}) {
  final toolCalls = callIds
      .map((id) => {
            'id': id,
            'name': 'search',
            'arguments': '{"q":"x"}',
          })
      .toList();
  final toolResults = callIds
      .map((id) => {
            'id': id,
            'result': 'result-for-$id',
          })
      .toList();
  return MessageEntity(
    chatId: 1,
    role: 'assistant',
    content: content,
    toolCalls: jsonEncode(toolCalls),
    toolResults: jsonEncode(toolResults),
  );
}

/// Asserts the OpenAI pairing contract on a produced message list:
/// 1. Every `tool` message is immediately preceded by an `assistant` message
///    whose tool_calls contain the matching id.
/// 2. Every assistant message carrying tool_calls is immediately followed by
///    a `tool` message for each call id (no tool_calls left without results).
void _assertPairingValid(List<ChatMessage> messages) {
  for (var i = 0; i < messages.length; i++) {
    final msg = messages[i];
    if (msg is ToolMessage) {
      expect(i, greaterThan(0),
          reason: 'tool message at index 0 has no preceding assistant');
      // A tool message is valid if its predecessor is either the
      // assistant-with-tool_calls or another tool message of the same group.
      final prev = messages[i - 1];
      final precededByAssistantOrTool =
          (prev is AssistantMessage && prev.hasToolCalls) || prev is ToolMessage;
      expect(precededByAssistantOrTool, isTrue,
          reason: 'tool message must be preceded by an assistant-with-tool_calls '
              'or another tool of the same group; found ${prev.runtimeType}');
    }
    if (msg is AssistantMessage && msg.hasToolCalls) {
      final ids = msg.toolCalls!.map((tc) => tc.id).toList();
      // The next `ids.length` messages must be tool messages matching each id.
      for (var j = 0; j < ids.length; j++) {
        final follow = messages[i + 1 + j];
        expect(follow, isA<ToolMessage>(),
            reason:
                'assistant tool_call ${ids[j]} not followed by a tool result');
        expect((follow as ToolMessage).toolCallId, ids[j],
            reason: 'tool result order/id mismatch for ${ids[j]}');
      }
    }
  }
}

void main() {
  group('ChatMessageService.buildMessages truncation', () {
    test('no truncation when context == 0 (unlimited)', () async {
      final messages = [
        _user('q1'),
        _assistantWithTools(callIds: ['call_1']),
        _user('q2'),
        _assistantText('done'),
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      _assertPairingValid(result);
      // 1 user + (assistant + 1 tool) + 1 user + 1 assistant = 5
      expect(result.length, 5);
    });

    // Auto mode (retention == -1): all messages preserved.
    test('auto mode preserves all messages', () async {
      final messages = [
        _user('q0'),
        _user('q1'),
        _assistantWithTools(callIds: ['call_a']),
        _user('q2'),
        _assistantText('a2'),
        _user('q3'),
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      _assertPairingValid(result);
      // assistant + tool + user + assistant + user + user + user = 7
      expect(result.length, 7);
    });

    // Zero context mode (retention == 0): only last user message.
    test('zero context mode returns only last user message', () async {
      final messages = [
        _user('q1'),
        _assistantWithTools(callIds: ['call_a']),
        _user('q2'),
        _assistantText('a2'),
        _user('latest'),
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(retention: 0),
        sentinel: null,
      );
      expect(result.length, 1);
      expect(result.first, isA<UserMessage>());
    });

    test('sentinel system prompt is prepended without breaking pairing',
        () async {
      final messages = [
        _user('q1'),
        _assistantWithTools(callIds: ['call_a']),
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: SentinelEntity(name: 'bot', prompt: 'you are a bot'),
      );
      expect(result.first, isA<SystemMessage>());
      _assertPairingValid(result.sublist(1));
    });
  });

  group('dangling tool_calls without tool_results (cancelled runs)', () {
    test('assistant tool_calls with no results are dropped (no 400 on replay)',
        () async {
      final orphan = MessageEntity(
        chatId: 1,
        role: 'assistant',
        toolCalls: jsonEncode([
          {'id': 'call_a', 'name': 'search', 'arguments': '{}'},
        ]),
        // toolResults intentionally empty (cancelled mid-flight).
      );
      final service = ChatMessageService(
          messageRepository: _FakeMessageRepository([_user('q'), orphan]));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      final assistant = result.whereType<AssistantMessage>().single;
      // 无对应 tool 响应时丢弃 tool_calls——带 tool_calls 却无 tool
      // 消息会被 OpenAI 兼容端 400 拒绝，该聊天将无法继续。
      expect(assistant.hasToolCalls, isFalse);
      expect(assistant.content, isNull);
    });

    test('tool_calls with no result are dropped, covered ones are kept',
        () async {
      final partial = MessageEntity(
        chatId: 1,
        role: 'assistant',
        toolCalls: jsonEncode([
          {'id': 'call_a', 'name': 'search', 'arguments': '{}'},
          {'id': 'call_b', 'name': 'write', 'arguments': '{}'},
        ]),
        toolResults: jsonEncode([
          {'id': 'call_a', 'name': 'search', 'result': 'ok'},
        ]),
      );
      final service = ChatMessageService(
          messageRepository: _FakeMessageRepository([_user('q'), partial]));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      final assistant = result.whereType<AssistantMessage>().single;
      expect(assistant.toolCalls, hasLength(1));
      expect(assistant.toolCalls!.single.id, 'call_a');
      expect(result.whereType<ToolMessage>().single.toolCallId, 'call_a');
    });
  });

  group('empty assistant content serialization', () {
    test('empty content becomes null (avoids content:"" with tool_calls)',
        () async {
      final msg = MessageEntity(
        chatId: 1,
        role: 'assistant',
        content: '',
      );
      final service = ChatMessageService(
          messageRepository: _FakeMessageRepository([_user('q'), msg]));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      final assistant = result.whereType<AssistantMessage>().single;
      expect(assistant.content, isNull);
    });

    test('non-empty content is preserved', () async {
      final msg = MessageEntity(
        chatId: 1,
        role: 'assistant',
        content: 'hello',
      );
      final service = ChatMessageService(
          messageRepository: _FakeMessageRepository([_user('q'), msg]));
      final result = await service.buildMessages(
        chat: _chat(retention: -1),
        sentinel: null,
      );
      final assistant = result.whereType<AssistantMessage>().single;
      expect(assistant.content, 'hello');
    });
  });
}
