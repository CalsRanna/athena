import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/storage/prefs_into_setting_migration.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late FileStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'chat_model_id': 3,
      'chat_naming_model_id': 3,
      'sentinel_metadata_generation_model_id': 3,
    });
    home = await Directory.systemTemp.createTemp('athena_gui_ids_');
    DI.ensureInitialized(homeDirOverride: home.path);
    storage = GetIt.instance<FileStorage>();
    await storage.root.create(recursive: true);
    await storage.settingFile.writeAsString(
      'providers:\n  - id: 1\n    name: Test\n    enabled: true\n',
    );
    await storage.modelsFile.writeAsString(
      jsonEncode([
        {'id': 3, 'name': 'Model', 'model_id': 'test-model', 'provider_id': 1},
      ]),
    );
    await storage.load();
    // 生产上这一步在 main 的启动序列里（_bootstrapStorage）
    await const PrefsIntoSettingMigration().run(storage.userSettings);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await home.delete(recursive: true);
  });

  test('旧 GUI 模型偏好迁移到 UUID，重复启动保留选择', () async {
    final settings = GetIt.instance<SettingViewModel>();
    await settings.initSignals();
    final model = (await storage.modelRepository.getAllModels()).single;
    final provider =
        (await storage.providerRepository.getAllProviders()).single;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'chat_model_id',
      'chat_naming_model_id',
      'sentinel_metadata_generation_model_id',
    ]) {
      // prefs 里的整数已经搬进 setting.yaml 并换成了 UUID；源键被移除
      expect(prefs.get(key), isNull);
      expect(await storage.userSettings.getString(key), model.id);
    }
    expect(settings.chatModel.value?.id, model.id);
    expect(settings.chatNamingModel.value?.id, model.id);
    expect(settings.sentinelMetadataGenerationModel.value?.id, model.id);
    expect(settings.chatModelProvider.value?.id, provider.id);
    await storage.load();
    await settings.initSignals();
    expect(settings.chatModelId.value, model.id);
  });

  test('无角色草稿可创建会话，已有角色也能清除为空', () async {
    await GetIt.instance<SettingViewModel>().initSignals();
    final vm = GetIt.instance<ChatViewModel>();
    await vm.initSignals();
    vm.updateCurrentSentinel(SentinelViewModel.directChatSentinel);
    final chat = await vm.createChat();
    expect(chat, isNotNull, reason: vm.error.value);
    expect(chat!.sentinelId, isNull);
    final sentinel =
        (await storage.sentinelRepository.getAllSentinels()).single;
    await vm.updateSentinel(sentinel, chat: chat);
    final withSentinel = (await storage.sessionRepository.getChatById(
      chat.id!,
    ))!;
    expect(withSentinel.sentinelId, sentinel.id);
    await vm.updateSentinel(
      SentinelViewModel.directChatSentinel,
      chat: withSentinel,
    );
    expect(
      (await storage.sessionRepository.getChatById(chat.id!))!.sentinelId,
      isNull,
    );
    expect(await storage.sentinelRepository.getAllSentinels(), hasLength(1));
  });
}
