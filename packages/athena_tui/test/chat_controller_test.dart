import 'dart:io';

import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('athena_tui_controller_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<TuiDi> createDi() async {
    // homeDir 注入 tempDir:避免读到用户真实 ~/.athena/setting.yaml
    final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
    await di.initialize(syncModels: false);
    await di.chatController.initialize();
    // availableModels 现在只返回已配 key 的 provider 的模型;
    // 测试建第二个聊天需要模型,给 Deep Seek 配 key
    final providers = await di.chatController.availableProviders;
    final target = providers.firstWhere((p) => p.name == 'Deep Seek');
    await di.chatController.updateProviderApiKey(target, 'sk-test-123');
    return di;
  }

  group('流式期间聊天切换守卫', () {
    test('selectChat 在流式期间被拒绝', () async {
      final di = await createDi();
      final c = di.chatController;
      final original = c.currentChat.value!;

      // 造第二个聊天并切过去(非流式,应成功)
      final second = await di.manageService.createChat(
        model: (await c.availableModels).first,
        sentinel: (await c.availableSentinels).first,
      );
      await c.selectChat(second);
      expect(c.currentChat.value?.id, second.id);

      // 流式期间切换被拒绝,保持当前聊天不变
      c.isStreaming.value = true;
      await c.selectChat(original);
      expect(c.currentChat.value?.id, second.id);
      expect(c.messages.value.map((m) => m.chatId), everyElement(second.id));

      // 恢复后可切换
      c.isStreaming.value = false;
      await c.selectChat(original);
      expect(c.currentChat.value?.id, original.id);
    });

    test('newChat / deleteCurrentChat 在流式期间被拒绝', () async {
      final di = await createDi();
      final c = di.chatController;
      final beforeId = c.currentChat.value!.id;
      final countBefore = c.chatList.value.length;

      c.isStreaming.value = true;
      await c.newChat();
      expect(c.chatList.value.length, countBefore);
      await c.deleteCurrentChat();
      expect(c.currentChat.value!.id, beforeId);
      c.isStreaming.value = false;
    });

    test('跨聊天 RunEvent 增量不进入当前列表', () async {
      final di = await createDi();
      final c = di.chatController;
      final other = await di.manageService.createChat(
        model: (await c.availableModels).first,
        sentinel: (await c.availableSentinels).first,
      );
      expect(c.currentChat.value?.id, isNot(other.id));

      // 注入旧聊天(非当前)的流式事件:应被过滤
      c.handleRunEvent(RunMessageStored(MessageEntity(
        chatId: other.id!,
        role: 'assistant',
        content: '旧聊天的回复',
      )));
      await Future<void>.delayed(const Duration(milliseconds: 80)); // 等 50ms flush
      expect(
        c.messages.value.where((m) => m.content == '旧聊天的回复'),
        isEmpty,
      );

      // 当前聊天的增量正常进入
      c.handleRunEvent(RunMessageStored(MessageEntity(
        chatId: c.currentChat.value!.id!,
        role: 'assistant',
        content: '当前聊天的回复',
      )));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        c.messages.value.where((m) => m.content == '当前聊天的回复'),
        hasLength(1),
      );
    });
  });

  group('启动打开全新会话', () {
    test('initialize 每次启动新建聊天,不恢复上次会话', () async {
      final di = await createDi();
      final c = di.chatController;
      final firstChatId = c.currentChat.value!.id;

      // 模拟一次会话结束:已有聊天被"遗留"(createChat 不刷新 chatList,
      // 用仓库计数断言真实数量)
      final legacyChat = await di.manageService.createChat(
        model: (await c.availableModels).first,
        sentinel: (await c.availableSentinels).first,
      );
      final (_, historyBefore) = await di.manageService.getChats();
      expect(historyBefore.length, 2);

      // 模拟"下一次启动":重新 initialize(幂等跳过,故先清 currentChat
      // 模拟全新进程状态)——应打开**新**聊天而非恢复上次的 firstChat
      c.currentChat.value = null;
      await c.initialize();

      final (_, historyAfter) = await di.manageService.getChats();
      expect(historyAfter.length, 3, reason: '新建了一个聊天');
      expect(c.currentChat.value!.id, isNot(firstChatId),
          reason: '不应恢复上次会话');
      expect(c.currentChat.value!.id, isNot(legacyChat.id),
          reason: '也不应选中遗留聊天');
    });

    test('启动用持久化模型建聊天,provider 检查针对该模型', () async {
      final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);
      // 给 Deep Seek 配 key,并持久化一个 Deep Seek 模型为默认模型
      // (测试种子无 v4-flash,用 deepseek-chat)
      final providers = await di.chatController.availableProviders;
      await di.chatController.updateProviderApiKey(
        providers.firstWhere((p) => p.name == 'Deep Seek'),
        'sk-test-123',
      );
      final model = (await di.modelRepo.getAllModels())
          .firstWhere((m) => m.modelId == 'deepseek-chat');
      await di.userSettings.saveModelId('deepseek-chat');

      // 模拟启动:defaultModelId 指向 deepseek-chat
      final controller = ChatController(
        manageService: di.manageService,
        bridge: di.agentBridge,
        messageRepo: di.messageRepo,
        modelRepo: di.modelRepo,
        providerRepo: di.providerRepo,
        sentinelRepo: di.sentinelRepo,
        supportService: di.supportService,
        onModelSwitched: di.persistCurrentModelId,
        defaultModelId: 'deepseek-chat',
      );
      await controller.initialize();

      // 当前聊天用的是 deepseek-chat(而非默认的 Reasoner)
      expect(controller.currentModel.value?.modelId, 'deepseek-chat');
      // 无错误(Deep Seek 已配 key,deepseek-chat 的 provider 检查通过)
      expect(controller.error.value, isNull, reason: '不应报"未配置 key"');
      expect(model.providerId, isNotNull);

      // 再次新建对话(/new)仍用 defaultModelId 的模型
      await controller.newChat();
      expect(controller.currentModel.value?.modelId, 'deepseek-chat');
    });

    test('配置 key 与切换模型均清除"未配置 key"引导错误', () async {
      final di = TuiDi(dataDirectory: tempDir.path, homeDir: tempDir.path);
      await di.initialize(syncModels: false);
      await di.chatController.initialize();

      // 路径 1:配 key 清除。
      // 初始化后默认模型 Deep Seek 未配 key → 有引导错误
      expect(di.chatController.error.value, isNotNull);
      final providers = await di.chatController.availableProviders;
      await di.chatController.updateProviderApiKey(
        providers.firstWhere((p) => p.name == 'Deep Seek'),
        'sk-test-123',
      );
      expect(di.chatController.error.value, isNull);

      // 路径 2:切换模型清除。
      // 手工注入一个错误(模拟 newChat 的未配 key 残留),再 switchModel
      di.chatController.error.value = '当前模型 X 的 Provider 未配置 API key。';
      final models = await di.chatController.availableModels;
      await di.chatController.switchModel(models.first);
      expect(di.chatController.error.value, isNull);
    });

    test('TuiDi.workspace 传递工作区路径', () async {
      final dir = await Directory.systemTemp.createTemp('workspace_test_');
      final di = TuiDi(dataDirectory: tempDir.path, workspace: dir.path);
      expect(di.workspace, dir.path);
      await dir.delete(recursive: true);
    });
  });

  group('自动重命名', () {
    test('_titleFromText 截断到 30 字符加省略号', () {
      expect(
        ChatController.titleFromText('短标题'),
        '短标题',
      );
      final long = List.filled(40, '字').join();
      final title = ChatController.titleFromText(long);
      expect(title.length, 31);
      expect(title.endsWith('…'), isTrue);
    });

    test('_autoRename 取首条用户消息而非最新回复', () async {
      final di = await createDi();
      final c = di.chatController;
      final chat = c.currentChat.value!;

      // 预置:用户消息 + assistant 回复(回复晚落库,行序在后)
      final userMsg = MessageEntity(
        chatId: chat.id!,
        role: 'user',
        content: '帮我写一个排序算法',
      );
      await di.messageRepo.storeMessage(userMsg);
      final reply = MessageEntity(
        chatId: chat.id!,
        role: 'assistant',
        content: '这是回复内容,不应成为标题',
      );
      await di.messageRepo.storeMessage(reply);

      // 触发自动重命名路径
      await c.autoRenameForTest(chat);
      final updated = await di.chatRepo.getChatById(chat.id!);
      expect(updated!.title, '帮我写一个排序算法');
    });
  });
}
