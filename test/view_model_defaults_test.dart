import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/di.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena/view_model/delegate/chat_config_delegate.dart';
import 'package:athena/view_model/delegate/chat_list_delegate.dart';
import 'package:athena/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  setUpAll(() {
    DI.ensureInitialized();
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  group('SentinelViewModel.defaultSentinel', () {
    test('falls back to Athena when no sentinels are loaded', () {
      final viewModel = SentinelViewModel(
        sentinelRepository: SentinelRepository(),
        providerRepository: ProviderRepository(),
        modelRepository: ModelRepository(),
        sentinelService: SentinelService(),
      );

      final sentinel = viewModel.defaultSentinel.value;

      expect(sentinel.name, 'Athena');
      expect(sentinel.prompt, isNotEmpty);
    });

    test('prefers the stored Athena sentinel when available', () {
      final viewModel = SentinelViewModel(
        sentinelRepository: SentinelRepository(),
        providerRepository: ProviderRepository(),
        modelRepository: ModelRepository(),
        sentinelService: SentinelService(),
      );
      final storedAthena = SentinelEntity(
        id: 2,
        name: 'Athena',
        prompt: 'stored prompt',
      );

      viewModel.sentinels.value = [
        SentinelEntity(id: 1, name: 'Custom'),
        storedAthena,
      ];

      expect(viewModel.defaultSentinel.value.id, storedAthena.id);
      expect(viewModel.defaultSentinel.value.prompt, 'stored prompt');
    });
  });

  group('ChatViewModel draft defaults', () {
    test('start from the shared new chat defaults', () {
      final viewModel = ChatViewModel(
        listDelegate: ChatListDelegate(
          manageService: ChatManageService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            modelRepository: ModelRepository(),
            providerRepository: ProviderRepository(),
            sentinelRepository: SentinelRepository(),
          ),
          supportService: ChatSupportService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            providerRepository: ProviderRepository(),
            chatService: ChatService(),
          ),
        ),
        configDelegate: ChatConfigDelegate(
          supportService: ChatSupportService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            providerRepository: ProviderRepository(),
            chatService: ChatService(),
          ),
        ),
        streamDelegate: AgentStreamDelegate(
          agentService: AgentService(
            chatService: ChatService(),
            toolRegistry: ToolRegistry(),
          ),
          manageService: ChatManageService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            modelRepository: ModelRepository(),
            providerRepository: ProviderRepository(),
            sentinelRepository: SentinelRepository(),
          ),
          messageService: ChatMessageService(
            messageRepository: MessageRepository(),
          ),
          messageRepo: MessageRepository(),
          modelRepo: ModelRepository(),
          sentinelRepo: SentinelRepository(),
          supportService: ChatSupportService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            providerRepository: ProviderRepository(),
            chatService: ChatService(),
          ),
          settingViewModel: SettingViewModel(
            modelRepository: ModelRepository(),
            providerRepository: ProviderRepository(),
            sentinelRepository: SentinelRepository(),
            chatRepository: ChatRepository(),
            chatService: ChatService(),
          ),
          permissionService: PermissionService(store: PermissionStore()),
          skillRegistry: SkillRegistry(),
        ),
        renameDelegate: ChatRenameDelegate(
          messageRepo: MessageRepository(),
          modelRepo: ModelRepository(),
          supportService: ChatSupportService(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository(),
            providerRepository: ProviderRepository(),
            chatService: ChatService(),
          ),
        ),
        supportService: ChatSupportService(
          chatRepository: ChatRepository(),
          messageRepository: MessageRepository(),
          providerRepository: ProviderRepository(),
          chatService: ChatService(),
        ),
        settingViewModel: SettingViewModel(
          modelRepository: ModelRepository(),
          providerRepository: ProviderRepository(),
          sentinelRepository: SentinelRepository(),
          chatRepository: ChatRepository(),
          chatService: ChatService(),
        ),
        modelViewModel: ModelViewModel(
          repository: ModelRepository(),
          providerRepository: ProviderRepository(),
          chatService: ChatService(),
        ),
        sentinelViewModel: SentinelViewModel(
          sentinelRepository: SentinelRepository(),
          providerRepository: ProviderRepository(),
          modelRepository: ModelRepository(),
          sentinelService: SentinelService(),
        ),
      );

      expect(viewModel.currentContext.value, ChatViewModel.defaultDraftContext);
      expect(
        viewModel.currentTemperature.value,
        ChatViewModel.defaultDraftTemperature,
      );
    });
  });
}
