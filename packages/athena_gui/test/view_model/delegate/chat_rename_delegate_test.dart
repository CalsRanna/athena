import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026);
  final chat = ChatEntity(
    id: 'chat',
    title: 'old',
    modelId: 'model',
    sentinelId: null,
    createdAt: now,
    updatedAt: now,
  );
  late _Messages messages;
  late _RenameService service;
  late ChatRenameDelegate subject;
  late List<String> titles;

  setUp(() {
    messages = _Messages();
    service = _RenameService();
    subject = ChatRenameDelegate(
      messageRepo: messages,
      modelRepo: _Models(),
      supportService: service,
    );
    titles = [];
  });

  tearDown(() async {
    subject.cancel(chat.id!);
    for (final request in service.requests) {
      await request.controller.close();
    }
  });

  test('正常流逐段通知，最终标题去掉两侧空白后保存', () async {
    final pending = subject.rename(chat: chat, onTitle: titles.add);
    await service.started.future;
    final request = service.requests.single;
    request.controller.add(' New');
    request.controller.add(' title ');
    await request.controller.close();
    expect((await pending)?.title, 'New title');
    expect(titles, [' New', ' New title ']);
    expect(service.saved, ['New title']);
  });

  test('首包未返回时取消也会结束请求，不等待新内容', () async {
    final pending = subject.rename(chat: chat, onTitle: titles.add);
    await service.started.future;
    subject.cancel(chat.id!);
    expect(await pending.timeout(const Duration(seconds: 1)), isNull);
    expect(service.requests.single.cancelled, isTrue);
    expect(titles, isEmpty);
    expect(service.saved, isEmpty);
  });

  test('查询期间取消不会继续启动标题请求', () async {
    final gate = Completer<List<MessageEntity>>();
    messages.pending = gate.future;
    final pending = subject.rename(chat: chat, onTitle: titles.add);
    subject.cancel(chat.id!);
    gate.complete(messages.items);
    expect(await pending, isNull);
    expect(service.requests, isEmpty);
  });

  test('替换请求会取消旧流，旧任务收尾不丢失新任务取消入口', () async {
    final first = subject.rename(chat: chat, onTitle: titles.add);
    await service.started.future;
    final old = service.requests.single;
    service.started = Completer<void>();
    final second = subject.rename(chat: chat, onTitle: titles.add);
    await service.started.future;
    expect(await first, isNull);
    expect(old.cancelled, isTrue);
    subject.cancel(chat.id!);
    expect(await second.timeout(const Duration(seconds: 1)), isNull);
    expect(service.requests.last.cancelled, isTrue);
    expect(service.saved, isEmpty);
  });
}

class _Messages extends Fake implements MessageRepository {
  final items = [
    MessageEntity(
      id: 'message',
      chatId: 'chat',
      role: 'user',
      content: 'Hello',
    ),
  ];
  Future<List<MessageEntity>>? pending;

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    String chatId, {
    bool includeCompacted = true,
  }) => pending ?? Future.value(items);
}

class _Models extends Fake implements ModelRepository {
  @override
  Future<ModelEntity?> getModelById(String id) async => ModelEntity(
    id: id,
    name: 'Test',
    modelId: 'test',
    providerId: 'provider',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _RenameService extends Fake implements ChatUpdateService {
  Completer<void> started = Completer<void>();
  final requests = <_Request>[];
  final saved = <String>[];

  @override
  Future<ProviderEntity?> getProviderForModel(String providerId) async =>
      ProviderEntity(
        id: providerId,
        name: 'Test',
        baseUrl: 'https://example.com/v1',
        apiKey: '',
        createdAt: DateTime(2026),
      );

  @override
  Stream<String> renameChat(
    String firstUserMessage, {
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) {
    final request = _Request();
    requests.add(request);
    unawaited(
      cancelSignal?.then((_) {
        request.cancelled = true;
        if (!request.controller.isClosed) {
          request.controller.addError(const CancelledException());
          unawaited(request.controller.close());
        }
      }),
    );
    started.complete();
    return request.controller.stream;
  }

  @override
  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) async {
    saved.add(title);
    return chat.copyWith(title: title);
  }
}

class _Request {
  final controller = StreamController<String>();
  bool cancelled = false;
}
