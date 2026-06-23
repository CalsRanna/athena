import 'package:athena/entity/chat_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements ChatRepository {
  final List<ChatEntity> updates = [];

  @override
  Future<void> updateChat(ChatEntity chat) async {
    updates.add(chat);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMessageRepository implements MessageRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProviderRepository implements ProviderRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService implements ChatService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatSupportService touches updated_at', () {
    late _FakeChatRepository fakeRepo;
    late ChatSupportService service;
    late ChatEntity original;

    setUp(() {
      fakeRepo = _FakeChatRepository();
      service = ChatSupportService(
        chatRepository: fakeRepo,
        messageRepository: _FakeMessageRepository(),
        providerRepository: _FakeProviderRepository(),
        chatService: _FakeChatService(),
      );
      original = ChatEntity(
        id: 1,
        title: 'old',
        modelId: 10,
        sentinelId: 20,
        temperature: 1.0,
        retention: -1,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
    });

    test('updateModel touches updatedAt', () async {
      final out = await service.updateModel(original, 99);
      expect(out.modelId, 99);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
      expect(fakeRepo.updates.single.modelId, 99);
    });

    test('updateSentinel touches updatedAt', () async {
      final out = await service.updateSentinel(original, 88);
      expect(out.sentinelId, 88);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('updateRetention touches updatedAt', () async {
      final out = await service.updateRetention(original, 0);
      expect(out.retention, 0);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('updateTemperature touches updatedAt', () async {
      final out = await service.updateTemperature(original, 0.5);
      expect(out.temperature, 0.5);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('renameChatManually touches updatedAt', () async {
      final out = await service.renameChatManually(original, 'new');
      expect(out.title, 'new');
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });
  });
}
