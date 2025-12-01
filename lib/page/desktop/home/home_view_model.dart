import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/entity/server_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/repository/server_repository.dart';
import 'package:signals/signals.dart';

class HomeViewModel {
  final chats = Signal<List<ChatEntity>>([]);
  final currentChat = Signal<ChatEntity?>(null);
  final currentModel = Signal<ModelEntity?>(null);
  final currentProvider = Signal<ProviderEntity?>(null);
  final currentSentinel = Signal<SentinelEntity?>(null);
  final availableModels = Signal<List<ModelEntity>>([]);
  final availableSentinels = Signal<List<SentinelEntity>>([]);
  final availableServers = Signal<List<ServerEntity>>([]);
  final images = Signal<List<String>>([]);
  final processing = Signal<bool>(false);

  final _chatRepository = ChatRepository();
  final _modelRepository = ModelRepository();
  final _providerRepository = ProviderRepository();
  final _sentinelRepository = SentinelRepository();
  final _serverRepository = ServerRepository();

  Future<void> initSignals() async {
    chats.value = await _chatRepository.getAllChats();
    availableSentinels.value = await _sentinelRepository.getAllSentinels();
    availableModels.value = await _modelRepository.getAllModels();
    availableServers.value = await _serverRepository.getAllServers();
    currentChat.value = chats.value.firstOrNull;
    if (currentChat.value == null) return;
    currentSentinel.value = availableSentinels.value
        .where((sentinel) => sentinel.id == currentChat.value!.sentinelId)
        .firstOrNull;
    currentModel.value = availableModels.value
        .where((model) => model.id == currentChat.value!.modelId)
        .firstOrNull;
    if (currentModel.value == null) return;
    currentProvider.value = await _providerRepository.getProviderById(
      currentModel.value!.providerId,
    );
  }
}
