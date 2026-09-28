import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_tui/bridge/tui_agent_bridge.dart';
import 'package:test/test.dart';

/// 审批与提问要带上发起的会话与取消信号：自动汇报 run 会在非当前会话上
/// 发起请求，UI 按会话标注、排队；run 取消时 UI 据此撤下卡片。
void main() {
  late Directory temp;
  late TuiAgentBridge bridge;
  late ToolRegistry registry;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_tui_bridge_');
    final storage = FileStorage(root: Directory('${temp.path}/.athena'));
    await storage.load();
    final chatService = ChatCompletionsService(llmClient: LlmClient());
    registry = ToolRegistry();
    bridge = TuiAgentBridge(
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
      experienceRepository: ExperienceRepository(homeDir: temp.path),
    );
  });

  tearDown(() async {
    await registry.backgroundTasks.dispose();
    await temp.delete(recursive: true);
  });

  test('审批请求带上发起的会话；run 取消时立即按拒绝返回并通知 UI', () async {
    String? seenChat;
    var uiNotified = false;
    bridge.permissionHandler = (chatId, toolName, arguments, cancelled) {
      seenChat = chatId;
      cancelled.then((_) => uiNotified = true);
      return Completer<Never>().future; // 用户迟迟不作答
    };

    final token = CancelToken();
    final decision = bridge.requestPermissionForTest(
      'bash',
      '{}',
      chatId: '7',
      cancelToken: token,
    );
    await Future<void>.delayed(Duration.zero); // 让请求先到达 UI
    token.cancel();

    expect((await decision).approved, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(seenChat, '7');
    expect(uiNotified, isTrue, reason: 'UI 要据此撤下这张卡片');
  });

  test('提问同样带上会话；取消时按未作答返回', () async {
    String? seenChat;
    bridge.elicitHandler = (chatId, questions, cancelled) {
      seenChat = chatId;
      return Completer<Map<String, String>?>().future;
    };

    final token = CancelToken();
    final answers = bridge.requestElicitForTest(
      const [
        ElicitQuestion(
          question: 'Which?',
          header: 'Pick',
          options: [
            ElicitOption(label: 'a', description: ''),
            ElicitOption(label: 'b', description: ''),
          ],
        ),
      ],
      chatId: '3',
      cancelToken: token,
    );
    token.cancel();

    expect(await answers, isNull);
    expect(seenChat, '3');
  });
}
