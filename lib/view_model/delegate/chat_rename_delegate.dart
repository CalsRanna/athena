import 'dart:async';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/service/chat_support_service.dart';

/// 聊天自动/手动重命名的委托。
///
/// 不持有 Signal，纯业务逻辑。重命名流式标题通过 [onTitle] 回调传出。
class ChatRenameDelegate {
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final ChatSupportService _supportService;
  final Map<int, CancelToken> _tokens = {};

  ChatRenameDelegate({
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required ChatSupportService supportService,
  })  : _messageRepo = messageRepo,
        _modelRepo = modelRepo,
        _supportService = supportService;

  /// 自动重命名：取首条用户消息 → AI 生成标题 → 写回数据库
  ///
  /// [onTitle] 在流式生成过程中被反复调用，用于更新 UI。
  /// 返回更新后的 [ChatEntity]，失败返回 null。
  Future<ChatEntity?> rename({
    required ChatEntity chat,
    required void Function(String title) onTitle,
  }) async {
    if (chat.id == null) return null;

    final token = CancelToken();
    _tokens[chat.id!] = token;

    try {
      final chatMessages = await _messageRepo.getMessagesByChatId(chat.id!);
      final firstUserMessage = chatMessages
          .where((m) => m.role == 'user')
          .firstOrNull;
      if (firstUserMessage == null) return null;

      final model = await _modelRepo.getModelById(chat.modelId);
      if (model == null) return null;

      final provider = await _supportService.getProviderForModel(
        model.providerId,
      );
      if (provider == null) return null;

      final titleBuffer = StringBuffer();
      final stream = _supportService.renameChat(
        firstUserMessage.content,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        if (token.isCancelled) return null;
        titleBuffer.write(chunk);
        onTitle(titleBuffer.toString());
      }

      final title = titleBuffer.toString().trim();
      if (title.isEmpty) return null;
      if (token.isCancelled) return null;

      return await _supportService.renameChatManually(chat, title);
    } catch (_) {
      return null;
    } finally {
      _tokens.remove(chat.id);
    }
  }

  /// 手动重命名
  Future<ChatEntity> renameManually({
    required ChatEntity chat,
    required String title,
  }) async {
    return _supportService.renameChatManually(chat, title);
  }

  /// 取消指定 chat 的进行中重命名流，防止写入已删除的 chat
  void cancel(int chatId) {
    _tokens[chatId]?.cancel();
    _tokens.remove(chatId);
  }
}
