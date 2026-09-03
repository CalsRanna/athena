import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_gui/entity/trpg_game_entity.dart';
import 'package:athena_gui/entity/trpg_message_entity.dart';
import 'package:athena_gui/repository/trpg_message_repository.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_gui/service/data_migration_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/view_model/trpg_view_model.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_gui/repository/sqlite_model_repository.dart';
import 'package:athena_gui/repository/sqlite_provider_repository.dart';
import 'package:athena_gui/repository/sqlite_sentinel_repository.dart';
import 'package:athena_gui/repository/sqlite_trpg_game_repository.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// 这些测试针对审计 C8：sendPlayerAction 缺少重入保护，快速二次调用会启动
// 两个并发 DM 流，覆盖状态并重复落库。修复后第一个语句即 isStreaming 守卫，
// 因此在已有流进行中时再次调用必须立即短路，不触碰 currentGame / 仓库。
//
// 方案：注入伪 TRPGMessageRepository 记录 createMessage 调用次数；其余依赖
// 以默认实例显式注入以避免 GetIt；将 isStreaming 置为 true 模拟进行中的流，
// 断言调用无副作用。

/// 记录 createMessage 调用次数的伪仓库。
class _RecordingMessageRepository extends TRPGMessageRepository {
  int createCount = 0;

  @override
  Future<int> createMessage(TRPGMessageEntity message) async {
    createCount++;
    return createCount;
  }

  @override
  Future<void> deleteMessagesByGameId(int gameId) async {}

  @override
  Future<void> deleteMessage(int messageId) async {}

  @override
  Future<int> getMessagesCountByGameId(int gameId) async => 0;

  @override
  Future<List<TRPGMessageEntity>> getMessagesByGameId(int gameId) async => [];
}

void main() {
  test('C8: 已有流进行中时 sendPlayerAction 立即短路，无副作用', () async {
    final messageRepository = _RecordingMessageRepository();
    // 显式注入全部依赖，避免构造时经 GetIt 解析。
    final getIt = GetIt.instance;
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: SqliteModelRepository(),
        providerRepository: SqliteProviderRepository(),
        llmClient: LlmClient(),
        dataMigrationService: DataMigrationService(
          providerRepo: SqliteProviderRepository(),
          modelRepo: SqliteModelRepository(),
          sentinelRepo: SqliteSentinelRepository(),
          chatRepo: SqliteChatRepository(),
        ),
        agentSettings: AgentSettings(),
      ),
    );

    final vm = TRPGViewModel(
      gameRepository: SqliteTRPGGameRepository(),
      messageRepository: messageRepository,
      modelRepository: SqliteModelRepository(),
      providerRepository: SqliteProviderRepository(),
      settingViewModel: getIt<SettingViewModel>(),
      modelResolver: ModelResolver(
        modelRepo: SqliteModelRepository(),
        providerRepo: SqliteProviderRepository(),
      ),
      agentService: AgentService(
        chatService: ChatService(llmClient: LlmClient()),
        toolRegistry: ToolRegistry(),
      ),
    );

    addTearDown(() async {
      await GetIt.instance.reset();
    });

    // 设置一个非空当前游戏：这样若缺少守卫，sendPlayerAction 会越过
    // game==null 检查并创建玩家消息（createCount 变为 1）。有守卫时则在
    // 创建消息之前短路——使下面 createCount==0 成为真正能捕获回归的判别。
    vm.currentGame.value = TRPGGameEntity(
      id: 1,
      modelId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    // 模拟一轮 DM 流正在进行中。
    vm.isStreaming.value = true;

    // 第二次调用应被重入守卫短路（守卫是方法首条语句）。
    await vm.sendPlayerAction('x');

    // 关键判别：守卫在 createMessage 之前返回 → 无任何仓库写入。
    // 缺少守卫时（currentGame 已非空）此处会是 1，故该断言能真正捕获回归。
    expect(messageRepository.createCount, 0);
    // 没有创建任何玩家消息。
    expect(vm.messages.value, isEmpty);
    // 错误信号未被设置。
    expect(vm.error.value, isNull);
  });
}
