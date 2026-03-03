import 'package:athena/entity/memory_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/memory_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/memory_service.dart';
import 'package:athena/util/logger_util.dart';
import 'package:signals/signals.dart';

class MemoryViewModel {
  final MemoryRepository _memoryRepository = MemoryRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final MessageRepository _messageRepository = MessageRepository();
  final ProviderRepository _providerRepository = ProviderRepository();
  final MemoryService _memoryService = MemoryService();

  final memory = signal<MemoryEntity?>(null);
  final isGenerating = signal(false);
  final progress = signal('');
  final error = signal<String?>(null);

  bool _cancelled = false;

  Future<void> loadMemory() async {
    var result = await _memoryRepository.getMemory();
    if (result != null) {
      result = result.copyWith(content: _stripCodeFences(result.content));
    }
    memory.value = result;
  }

  Future<void> generateMemory(ModelEntity model) async {
    _cancelled = false;
    isGenerating.value = true;
    error.value = null;
    progress.value = '准备中...';

    try {
      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) {
        error.value = '未找到对应的提供商';
        isGenerating.value = false;
        return;
      }

      var lastChatId = memory.value?.lastChatId ?? 0;
      var existingMemories = '';
      var batchIndex = 0;

      while (true) {
        if (_cancelled) {
          progress.value = '已取消';
          break;
        }

        var chats = await _chatRepository.getChatsAfterId(
          lastChatId,
          limit: 10,
        );
        if (chats.isEmpty) break;

        batchIndex++;
        progress.value = '正在分析第 $batchIndex 批对话...';

        var chatDataBuffer = StringBuffer();
        for (var chat in chats) {
          if (chat.id == null) continue;
          var messages = await _messageRepository.getMessagesByChatId(chat.id!);
          chatDataBuffer.writeln('--- 对话: ${chat.title} ---');
          for (var message in messages) {
            var content = message.content;
            if (content.length > 500) {
              content = '${content.substring(0, 500)}...';
            }
            chatDataBuffer.writeln('[${message.role}]: $content');
          }
          chatDataBuffer.writeln();
        }

        var chatData = chatDataBuffer.toString();
        if (chatData.trim().isEmpty) {
          lastChatId = chats.last.id!;
          continue;
        }

        existingMemories = await _memoryService.analyzeBatch(
          existingMemories: existingMemories,
          chatData: chatData,
          provider: provider,
          model: model,
        );

        lastChatId = chats.last.id!;

        // 保存增量进度
        var now = DateTime.now();
        var intermediateMemory = MemoryEntity(
          content: existingMemories,
          lastChatId: lastChatId,
          lastChatUpdatedAt: chats.last.updatedAt,
          createdAt: memory.value?.createdAt ?? now,
          updatedAt: now,
        );
        await _memoryRepository.saveMemory(intermediateMemory);
        memory.value = intermediateMemory;
      }

      if (_cancelled) {
        isGenerating.value = false;
        return;
      }

      if (existingMemories.isEmpty) {
        progress.value = '没有找到可分析的对话数据';
        isGenerating.value = false;
        return;
      }

      // 最终综合生成
      progress.value = '正在整理记忆...';
      var synthesized = await _memoryService.synthesize(
        memoryData: existingMemories,
        provider: provider,
        model: model,
      );
      synthesized = _stripCodeFences(synthesized);

      var now = DateTime.now();
      var finalMemory = MemoryEntity(
        content: synthesized,
        lastChatId: lastChatId,
        lastChatUpdatedAt: memory.value?.lastChatUpdatedAt ?? now,
        createdAt: memory.value?.createdAt ?? now,
        updatedAt: now,
      );
      await _memoryRepository.saveMemory(finalMemory);
      memory.value = finalMemory;
      progress.value = '生成完成';
    } catch (e) {
      LoggerUtil.e('生成记忆失败', error: e);
      error.value = '生成失败: $e';
    } finally {
      isGenerating.value = false;
    }
  }

  void cancelGeneration() {
    _cancelled = true;
  }

  Future<void> deleteMemory() async {
    await _memoryRepository.deleteMemory();
    memory.value = null;
  }

  String _stripCodeFences(String content) {
    var trimmed = content.trim();
    var pattern = RegExp(r'^```\w*\n?([\s\S]*?)\n?```$');
    var match = pattern.firstMatch(trimmed);
    if (match != null) return match.group(1)?.trim() ?? trimmed;
    return trimmed;
  }
}
