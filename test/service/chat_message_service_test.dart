import 'dart:convert';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart';

/// A fake [MessageRepository] that returns a fixed list of [MessageEntity],
/// allowing [ChatMessageService.buildMessages] to be driven deterministically
/// without a database.
class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository(this._messages);

  final List<MessageEntity> _messages;

  @override
  Future<List<MessageEntity>> getMessagesByChatId(int chatId) async =>
      _messages;
}

ChatEntity _chat({required int context}) => ChatEntity(
      id: 1,
      title: 'test',
      modelId: 1,
      sentinelId: 1,
      context: context,
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
        chat: _chat(context: 0),
        sentinel: null,
      );
      _assertPairingValid(result);
      // 1 user + (assistant + 1 tool) + 1 user + 1 assistant = 5
      expect(result.length, 5);
    });

    // Boundary: contextLimit = context*2. With many entities, the sublist cut
    // point is forced to land exactly before / on / after an
    // assistant-with-tool_calls entity. Because truncation is entity-level and
    // the assistant+results are emitted atomically from ONE entity, the cut can
    // never split a tool group.
    test('cut point lands immediately BEFORE the tool-call entity', () async {
      // 6 entities; context=2 => keep last 4. Tool entity at index 2 is kept,
      // with the boundary right at its left edge.
      final messages = [
        _user('q0'), // index 0 - dropped
        _user('q1'), // index 1 - dropped
        _assistantWithTools(callIds: ['call_a']), // index 2 - first kept
        _user('q2'), // index 3
        _assistantText('a2'), // index 4
        _user('q3'), // index 5
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(context: 2),
        sentinel: null,
      );
      _assertPairingValid(result);
      // Kept entities: [assistantWithTools, user, assistant, user]
      // => assistant + tool + user + assistant + user = 5 messages
      expect(result.length, 5);
      expect(result.first, isA<AssistantMessage>());
      expect((result.first as AssistantMessage).hasToolCalls, isTrue);
      expect(result[1], isA<ToolMessage>());
    });

    test('cut point lands immediately AFTER the tool-call entity', () async {
      // 6 entities; context=2 => keep last 4. Tool entity at index 1 is the
      // LAST dropped entity, so the boundary is right at its right edge.
      final messages = [
        _user('q0'), // index 0 - dropped
        _assistantWithTools(callIds: ['call_a']), // index 1 - dropped (last)
        _user('q2'), // index 2 - first kept
        _assistantText('a2'), // index 3
        _user('q3'), // index 4
        _assistantText('a3'), // index 5
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(context: 2),
        sentinel: null,
      );
      _assertPairingValid(result);
      // The dropped tool entity took BOTH its tool_calls and tool_results with
      // it, so there is no orphan tool message at the head.
      expect(result.first, isA<UserMessage>());
      // No tool message should appear at all (the only tool group was dropped).
      expect(result.whereType<ToolMessage>(), isEmpty);
    });

    test('multiple consecutive tool-call entities (no truncation at this limit)',
        () async {
      // Two tool entities; only the second survives a context=1 cut.
      final messages = [
        _assistantWithTools(callIds: ['call_x', 'call_y']), // dropped
        _assistantWithTools(callIds: ['call_z']), // kept (last entity)
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(context: 1), // limit = 2; len 2 not > 2 => NO truncation
        sentinel: null,
      );
      _assertPairingValid(result);
      // len(2) is not > limit(2), so nothing is truncated: both groups present.
      // assistant(2 calls) + tool + tool + assistant(1 call) + tool = 5
      expect(result.length, 5);
    });

    test('truncation actually triggers and preserves surviving tool group',
        () async {
      // 5 entities, context=1 => limit=2, keep last 2 entities.
      final messages = [
        _user('q0'), // dropped
        _assistantWithTools(callIds: ['call_a']), // dropped
        _user('q1'), // dropped
        _assistantWithTools(callIds: ['call_b', 'call_c']), // kept
        _user('q2'), // kept
      ];
      final service =
          ChatMessageService(messageRepository: _FakeMessageRepository(messages));
      final result = await service.buildMessages(
        chat: _chat(context: 1),
        sentinel: null,
      );
      _assertPairingValid(result);
      // Kept: [assistantWithTools(2 calls), user]
      // => assistant + tool + tool + user = 4
      expect(result.length, 4);
      expect(result.first, isA<AssistantMessage>());
      final assistant = result.first as AssistantMessage;
      expect(assistant.toolCalls!.map((t) => t.id), ['call_b', 'call_c']);
      expect((result[1] as ToolMessage).toolCallId, 'call_b');
      expect((result[2] as ToolMessage).toolCallId, 'call_c');
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
        chat: _chat(context: 0),
        sentinel: SentinelEntity(name: 'bot', prompt: 'you are a bot'),
      );
      expect(result.first, isA<SystemMessage>());
      _assertPairingValid(result.sublist(1));
    });
  });

  // Observation-only: an assistant entity persisted mid-flight with tool_calls
  // but EMPTY tool_results. This is OUTSIDE C10's truncation scope (it is not
  // caused by truncation), documented here as a characterization of current
  // behavior: such an entity yields an assistant-with-tool_calls and NO tool
  // results, which would be rejected by strict endpoints regardless of
  // truncation.
  group('observation: empty tool_results (non-truncation pairing risk)', () {
    test('assistant with tool_calls but empty tool_results yields no results',
        () async {
      final orphan = MessageEntity(
        chatId: 1,
        role: 'assistant',
        toolCalls: jsonEncode([
          {'id': 'call_a', 'name': 'search', 'arguments': '{}'},
        ]),
        // toolResults intentionally empty (mid-flight persistence).
      );
      final service = ChatMessageService(
          messageRepository: _FakeMessageRepository([_user('q'), orphan]));
      final result = await service.buildMessages(
        chat: _chat(context: 0),
        sentinel: null,
      );
      final assistant = result.whereType<AssistantMessage>().single;
      expect(assistant.hasToolCalls, isTrue);
      // Demonstrates the gap: tool_calls present, but zero tool results.
      expect(result.whereType<ToolMessage>(), isEmpty);
    });
  });
}
