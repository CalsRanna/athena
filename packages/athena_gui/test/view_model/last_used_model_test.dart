import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// 新会话从「上次在 composer 里选的模型」起步：显式切换要写偏好，
/// 打开旧会话与自动补位都不写。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late FileStorage storage;
  late SettingViewModel settings;
  late ChatViewModel chats;
  late String modelAId;
  late String modelBId;

  const key = 'chat_model_id';

  ModelEntity newModel(String name, String providerId) => ModelEntity(
    name: name,
    modelId: name.toLowerCase(),
    providerId: providerId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<ModelEntity> loadModel(String id) async =>
      (await storage.modelRepository.getModelById(id))!;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('athena_last_model_');
    DI.ensureInitialized(homeDirOverride: home.path);
    storage = GetIt.instance<FileStorage>();
    await storage.load();
    final providerId = await storage.providerRepository.storeProvider(
      ProviderEntity(
        name: 'P',
        baseUrl: 'https://example.invalid/v1',
        apiKey: 'k',
        enabled: true,
        createdAt: DateTime(2026),
      ),
    );
    modelAId = await storage.modelRepository.createModel(
      newModel('Model A', providerId),
    );
    modelBId = await storage.modelRepository.createModel(
      newModel('Model B', providerId),
    );
    settings = GetIt.instance<SettingViewModel>();
    chats = GetIt.instance<ChatViewModel>();
    await settings.initSignals();
    await chats.initSignals();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await home.delete(recursive: true);
  });

  test('草稿里换模型会记住，新草稿从它起步', () async {
    final modelB = await loadModel(modelBId);
    await chats.updateCurrentModel(modelB);

    expect(await storage.userSettings.getString(key), modelBId);
    expect(settings.chatModel.value?.id, modelBId);

    // 重启后偏好仍在：重新读设置，再从草稿起步
    await settings.initSignals();
    await chats.prepareNewChatDraft();
    expect(chats.currentModel.value?.id, modelBId);
  });

  test('已有会话里换模型同样记住，打开别的会话不改写', () async {
    final chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 't',
        modelId: modelAId,
        sentinelId: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final chat = (await storage.sessionRepository.getChatById(chatId))!;
    final modelB = await loadModel(modelBId);

    await chats.updateModel(modelB, chat: chat);
    expect(await storage.userSettings.getString(key), modelBId);

    // 点进一条模型是 A 的会话：只换当前值，不改偏好
    await chats.selectChat(chat.copyWith(modelId: modelAId));
    expect(await storage.userSettings.getString(key), modelBId);
    expect(chats.currentModel.value?.id, modelAId);
  });

  test('自动补位第一个可用模型不写偏好', () async {
    // 启动时草稿没有偏好值，走 adoptFirstAvailableModel 兜底
    expect(chats.currentModel.value?.id, modelAId);
    expect(await storage.userSettings.getString(key), isNull);
  });
}
