import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/storage/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// run 还没开始就失败（模型 / provider 找不到）时，错误要落进会话，而不是只发
/// 一个 [RunError]：否则用户消息下面什么都没有，重开会话也看不出原因。
void main() {
  late Directory tmp;
  late FileStorage storage;
  late AgentRunCoordinator coordinator;
  late ToolRegistry registry;
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_setup_error_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    await storage.load();
    final chatService = ChatCompletionsService(llmClient: LlmClient());
    registry = ToolRegistry();
    coordinator = AgentRunCoordinator(
      agentService: AgentService(
        chatService: chatService,
        toolRegistry: registry,
      ),
      manageService: ChatStoreService(
        chatRepository: storage.sessionRepository,
        messageRepository: storage.sessionRepository,
        modelRepository: storage.modelRepository,
        providerRepository: storage.providerRepository,
        sentinelRepository: storage.sentinelRepository,
      ),
      messageService: ChatMessageConverter(
        messageRepository: storage.sessionRepository,
      ),
      chatService: chatService,
      messageRepo: storage.sessionRepository,
      modelRepo: storage.modelRepository,
      sentinelRepo: storage.sentinelRepository,
      chatRepo: storage.sessionRepository,
      supportService: ChatUpdateService(
        chatRepository: storage.sessionRepository,
        providerRepository: storage.providerRepository,
        chatService: chatService,
      ),
      agentSettings: AgentSettings(),
      permissionService: PermissionService(store: PermissionStore()),
      permissionPrompt: (chatId, toolName, arguments, cancelToken) async =>
          const PermissionDecision(approved: false),
      experienceRepository: ExperienceRepository(homeDir: tmp.path),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await registry.backgroundTasks.dispose();
    await tmp.delete(recursive: true);
  });

  Future<(List<RunEvent>, List<MessageEntity>)> sendWithModel(
    String modelId,
  ) async {
    final chat = ChatEntity(
      title: 't',
      modelId: modelId,
      sentinelId: ChatEntity.noSentinelId,
      createdAt: now,
      updatedAt: now,
    );
    final chatId = await storage.sessionRepository.createChat(chat);
    final events = await coordinator
        .send(
          message: MessageEntity(chatId: chatId, role: 'user', content: 'hi'),
          chat: chat.copyWith(id: chatId),
        )
        .toList();
    final messages = await storage.sessionRepository.getMessagesByChatId(
      chatId,
    );
    return (events, messages);
  }

  test('模型不存在：错误作为 assistant 消息落库，并发出 RunError', () async {
    final (events, messages) = await sendWithModel('999');

    expect(messages.map((m) => m.role), ['user', 'assistant']);
    expect(messages.last.content, startsWith('Error: Model not found'));
    expect(
      events.whereType<RunAssistantAppended>().single.message.content,
      messages.last.content,
      reason: '界面靠这条事件把错误显示在会话里',
    );
    expect(events.whereType<RunError>(), hasLength(1));
  });

  test('删掉 provider 后，它的模型一并消失，不留孤儿', () async {
    // 模型现在存在所属 provider 的文件里,删 provider 就是删文件。
    // 旧的 models.json 布局下这两件事是分开的(先删 provider 再删模型),
    // 中间失败就会留下指向不存在 provider 的模型;这里断言那条路已经不存在。
    final providerId = await storage.providerRepository.storeProvider(
      ProviderEntity(
        name: 'Gone',
        baseUrl: 'https://gone.example/v1',
        apiKey: 'k',
        createdAt: now,
      ),
    );
    final modelId = await storage.modelRepository.createModel(
      ModelEntity(
        name: 'orphan',
        modelId: 'orphan-model',
        providerId: providerId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(await storage.modelRepository.getModelById(modelId), isNotNull);

    await storage.providerRepository.deleteProvider(providerId);

    expect(await storage.modelRepository.getModelById(modelId), isNull);
    expect(await storage.modelRepository.getAllModels(), isEmpty);

    // 会话仍引用着那个已消失的模型:报的是「模型不存在」,而不是「provider
    // 不存在」——后者在「模型与 provider 同文件」之后已不可达(模型读得出来
    // 就说明 provider 文件在)。coordinator 里仍保留 provider 为空的分支,
    // 那防的是两次读之间的竞态。
    final (_, messages) = await sendWithModel(modelId);
    expect(messages.last.role, 'assistant');
    expect(messages.last.content, startsWith('Error: Model not found'));
  });
}
