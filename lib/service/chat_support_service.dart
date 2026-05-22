import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class ChatSupportService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ProviderRepository _providerRepository;
  final ChatService _chatService;

  ChatSupportService({
    ChatRepository? chatRepository,
    MessageRepository? messageRepository,
    ProviderRepository? providerRepository,
    ChatService? chatService,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _messageRepository = messageRepository ?? MessageRepository(),
        _providerRepository = providerRepository ?? ProviderRepository(),
        _chatService = chatService ?? ChatService();

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

  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) async {
    final updated = chat.copyWith(title: title);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<Uint8List> exportImage(GlobalKey repaintBoundaryKey) async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Failed to get render boundary');

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to convert image to bytes');

    return byteData.buffer.asUint8List();
  }

  Future<String> saveImageFile(Uint8List bytes, int chatId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Failed to get downloads directory');
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    }
  }

  Future<ChatEntity> updateModel(ChatEntity chat, int modelId) async {
    final updated = chat.copyWith(modelId: modelId);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) async {
    final updated = chat.copyWith(sentinelId: sentinelId);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateContext(ChatEntity chat, int context) async {
    final updated = chat.copyWith(context: context);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateTemperature(
      ChatEntity chat, double temperature) async {
    final updated = chat.copyWith(temperature: temperature);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ProviderEntity?> getProviderForModel(int providerId) async {
    return _providerRepository.getProviderById(providerId);
  }

  Future<MessageEntity> updateExpanded(MessageEntity message) async {
    final updated = message.copyWith(expanded: !message.expanded);
    await _messageRepository.updateMessage(updated);
    return updated;
  }
}
