import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:test/test.dart';

class _FakeChatRepository implements ChatRepository {
  final List<ChatEntity> updates = [];

  /// 模拟持久化存储：getChatById 返回最近一次写入的实体。
  ChatEntity? stored;

  @override
  Future<void> updateChat(ChatEntity chat) async {
    updates.add(chat);
    stored = chat;
  }

  @override
  Future<ChatEntity?> getChatById(int id) async => stored;

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
      fakeRepo.stored = original;
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

  group('ChatSupportService field-level updates (no lost update)', () {
    test('update with stale snapshot does not clobber newer fields', () async {
      final fakeRepo = _FakeChatRepository();
      final service = ChatSupportService(
        chatRepository: fakeRepo,
        messageRepository: _FakeMessageRepository(),
        providerRepository: _FakeProviderRepository(),
        chatService: _FakeChatService(),
      );
      final original = ChatEntity(
        id: 1,
        title: 'old',
        modelId: 10,
        sentinelId: 20,
        temperature: 1.0,
        retention: -1,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
      fakeRepo.stored = original;

      // 场景：对话框持有旧快照 original，期间自动重命名把新标题落库
      await service.renameChatManually(original, 'auto-renamed');

      // 用户随后用旧快照保存温度——不得把标题回退为 'old'
      final out = await service.updateTemperature(original, 0.5);

      expect(out.title, 'auto-renamed',
          reason: '旧快照更新温度时不应覆盖已落库的新标题');
      expect(out.temperature, 0.5);
      expect(out.modelId, 10);
      expect(out.sentinelId, 20);
      expect(fakeRepo.updates.last.title, 'auto-renamed');
    });

    test('updateModel uses the latest row even with stale snapshot', () async {
      final fakeRepo = _FakeChatRepository();
      final service = ChatSupportService(
        chatRepository: fakeRepo,
        messageRepository: _FakeMessageRepository(),
        providerRepository: _FakeProviderRepository(),
        chatService: _FakeChatService(),
      );
      fakeRepo.stored = ChatEntity(
        id: 1,
        title: 't1',
        modelId: 10,
        sentinelId: 20,
        temperature: 1.0,
        retention: -1,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );

      // 调用方持有过期的 title，但最新行是 t1——更新模型不得覆盖它
      final stale = fakeRepo.stored!.copyWith(title: 'stale');
      final out = await service.updateModel(stale, 99);
      expect(out.title, 't1');
      expect(out.modelId, 99);
      expect(fakeRepo.updates.last.title, 't1');
    });
  });
}
