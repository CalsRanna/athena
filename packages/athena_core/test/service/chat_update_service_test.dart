import 'dart:async';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

void main() {
  late _Client client;
  late ChatUpdateService service;
  final provider = ProviderEntity(
    name: 'Test',
    baseUrl: 'https://example.com/v1',
    apiKey: '',
    createdAt: DateTime(2026),
  );
  final model = ModelEntity(
    name: 'Test',
    modelId: 'test',
    providerId: 'provider',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    client = _Client();
    service = ChatUpdateService(
      chatRepository: _Chats(),
      providerRepository: _Providers(),
      chatService: ChatCompletionsService(llmClient: client),
    );
  });
  tearDown(() => client.events.close());

  test('取消信号穿过标题服务，首包未返回时也能结束请求', () async {
    final token = CancelToken();
    final done = service
        .renameChat(
          'Hello',
          provider: provider,
          model: model,
          cancelSignal: token.whenCancelled,
        )
        .toList();
    final check = expectLater(done, throwsA(isA<CancelledException>()));
    await client.started.future;
    expect(client.cancelSignal, same(token.whenCancelled));
    token.cancel();
    await check.timeout(const Duration(seconds: 1));
  });

  test('不传取消信号时仍逐段返回标题内容', () async {
    final done = service
        .renameChat('Hello', provider: provider, model: model)
        .toList();
    await client.started.future;
    expect(client.cancelSignal, isNull);
    for (final content in ['New', ' title']) {
      client.events.add(
        ChatStreamEvent.fromJson({
          'id': 'title',
          'object': 'chat.completion.chunk',
          'created': 0,
          'model': 'test',
          'choices': [
            {
              'index': 0,
              'delta': {'content': content},
              'finish_reason': null,
            },
          ],
        }),
      );
    }
    await client.events.close();
    expect(await done, ['New', ' title']);
  });
}

class _Client extends LlmClient {
  final events = StreamController<ChatStreamEvent>();
  final started = Completer<void>();
  Future<void>? cancelSignal;

  @override
  Stream<ChatStreamEvent> stream({
    required ProviderEntity provider,
    required ChatCompletionCreateRequest request,
    Future<void>? cancelSignal,
    int outputLimit = 0,
    int? outputRoom,
  }) {
    this.cancelSignal = cancelSignal;
    unawaited(
      cancelSignal?.then((_) {
        if (events.isClosed) return;
        events.addError(const CancelledException());
        unawaited(events.close());
      }),
    );
    started.complete();
    return events.stream;
  }
}

class _Chats implements ChatRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Providers implements ProviderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
