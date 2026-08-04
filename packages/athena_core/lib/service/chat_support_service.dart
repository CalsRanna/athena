import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/chat_service.dart';

/// 会话辅助操作：重命名、配置更新、Provider 解析、消息折叠、图片导出。
class ChatSupportService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ProviderRepository _providerRepository;
  final ChatService _chatService;
  final Future<Directory> Function()? _mobileExportDirProvider;
  final Future<Directory?> Function()? _downloadsDirProvider;

  ChatSupportService({
    required ChatRepository chatRepository,
    required MessageRepository messageRepository,
    required ProviderRepository providerRepository,
    required ChatService chatService,
    Future<Directory> Function()? mobileExportDirProvider,
    Future<Directory?> Function()? downloadsDirProvider,
  }) : _chatRepository = chatRepository,
       _messageRepository = messageRepository,
       _providerRepository = providerRepository,
       _mobileExportDirProvider = mobileExportDirProvider,
       _downloadsDirProvider = downloadsDirProvider,
       _chatService = chatService;

  // ─── 重命名 ─────────────────────────────────────────────

  Stream<String> renameChat(
    String firstUserMessage, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    final stream = _chatService.getTitle(
      firstUserMessage,
      provider: provider,
      model: model,
    );
    yield* stream;
  }

  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) {
    return _touchChat(chat.copyWith(title: title));
  }

  // ─── 配置更新 ───────────────────────────────────────────

  Future<ChatEntity> updateModel(ChatEntity chat, int modelId) {
    return _touchChat(chat.copyWith(modelId: modelId));
  }

  Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) {
    return _touchChat(chat.copyWith(sentinelId: sentinelId));
  }

  Future<ChatEntity> updateRetention(ChatEntity chat, int retention) {
    return _touchChat(chat.copyWith(retention: retention));
  }

  Future<ChatEntity> updateTemperature(ChatEntity chat, double temperature) {
    return _touchChat(chat.copyWith(temperature: temperature));
  }

  // ─── 图片 ───────────────────────────────────────────────

  Future<String> saveImageFile(Uint8List bytes, int chatId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (PlatformUtil.isMobile) {
      final provider = _mobileExportDirProvider;
      if (provider == null) {
        throw UnsupportedError('mobileExportDirProvider not configured');
      }
      final directory = await provider();
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } else {
      final provider = _downloadsDirProvider;
      if (provider == null) {
        throw UnsupportedError('downloadsDirProvider not configured');
      }
      final directory = await provider();
      if (directory == null) {
        throw Exception('Failed to get downloads directory');
      }
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    }
  }

  // ─── Provider 解析 ──────────────────────────────────────

  Future<ProviderEntity?> getProviderForModel(int providerId) async {
    return _providerRepository.getProviderById(providerId);
  }

  // ─── 消息 ───────────────────────────────────────────────

  Future<MessageEntity> updateExpanded(MessageEntity message) async {
    final updated = message.copyWith(expanded: !message.expanded);
    await _messageRepository.updateMessage(updated);
    return updated;
  }

  // ─── 内部 ───────────────────────────────────────────────

  Future<ChatEntity> _touchChat(ChatEntity updated) async {
    final touched = updated.copyWith(updatedAt: DateTime.now());
    await _chatRepository.updateChat(touched);
    return touched;
  }
}
