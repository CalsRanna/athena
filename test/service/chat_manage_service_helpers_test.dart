import 'package:athena/entity/message_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessageRepository implements MessageRepository {
  final List<MessageEntity> stored = [];
  final List<MessageEntity> updated = [];
  int nextId = 100;

  @override
  Future<int> storeMessage(MessageEntity message) async {
    final id = nextId++;
    stored.add(message.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    updated.add(message);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubChatRepository implements ChatRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubModelRepository implements ModelRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubProviderRepository implements ProviderRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSentinelRepository implements SentinelRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatManageService helpers', () {
    late _FakeMessageRepository fakeRepo;
    late ChatManageService service;

    setUp(() {
      fakeRepo = _FakeMessageRepository();
      service = ChatManageService(
        chatRepository: _StubChatRepository(),
        messageRepository: fakeRepo,
        modelRepository: _StubModelRepository(),
        providerRepository: _StubProviderRepository(),
        sentinelRepository: _StubSentinelRepository(),
      );
    });

    test('appendAssistantPlaceholder stores empty assistant and returns id', () async {
      final result = await service.appendAssistantPlaceholder(7);

      expect(result.id, 100);
      expect(result.chatId, 7);
      expect(result.role, 'assistant');
      expect(result.content, '');
      expect(fakeRepo.stored.single.role, 'assistant');
    });

    test('finalizeAssistantMessage forwards to repository', () async {
      final msg = MessageEntity(id: 1, chatId: 1, role: 'assistant', content: 'hi');
      await service.finalizeAssistantMessage(msg);

      expect(fakeRepo.updated.single, msg);
    });

    test('recordCancelledOnMessage appends [Cancelled] and clears reasoning', () async {
      final msg = MessageEntity(
        id: 2,
        chatId: 1,
        role: 'assistant',
        content: 'partial answer',
        reasoning: true,
        reasoningContent: 'thinking...',
        toolCalls: '[]',
      );
      final out = await service.recordCancelledOnMessage(msg);

      expect(out.content, 'partial answer\n\n[Cancelled]');
      expect(out.reasoning, isFalse);
      expect(out.reasoningContent, 'thinking...');
      expect(out.toolCalls, '[]');
    });

    test('recordCancelledOnMessage on empty content yields bare marker', () async {
      final msg = MessageEntity(id: 3, chatId: 1, role: 'assistant', content: '');
      final out = await service.recordCancelledOnMessage(msg);

      expect(out.content, '[Cancelled]');
    });

    test('recordErrorOnMessage appends [Error: ...] and preserves toolCalls', () async {
      final msg = MessageEntity(
        id: 4,
        chatId: 1,
        role: 'assistant',
        content: 'partial',
        toolCalls: '[{"id":"a"}]',
        toolResults: '[{"id":"a","result":"r"}]',
      );
      final out = await service.recordErrorOnMessage(msg, 'boom');

      expect(out.content, 'partial\n\n[Error: boom]');
      expect(out.toolCalls, '[{"id":"a"}]');
      expect(out.toolResults, '[{"id":"a","result":"r"}]');
    });
  });
}
