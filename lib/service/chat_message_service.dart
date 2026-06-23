import 'dart:convert';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// 消息格式转换与上下文组装。
///
/// 职责：将 [MessageEntity] 列表转换为 OpenAI [ChatMessage] 列表
/// （含 system prompt 注入、上下文截断、tool_calls/tool_results 展开、
/// 图片 ContentPart 处理）。不涉及网络或持久化。
class ChatMessageService {
  final MessageRepository _messageRepository;

  ChatMessageService({
    required MessageRepository messageRepository,
  }) : _messageRepository = messageRepository;

  /// 将 Entity 消息列表转换为 OpenAI ChatMessage 列表
  ///
  /// 包含上下文截断、system prompt 插入、图片处理
  Future<List<ChatMessage>> buildMessages({
    required ChatEntity chat,
    required SentinelEntity? sentinel,
  }) async {
    final chatMessages = await _messageRepository.getMessagesByChatId(
      chat.id!,
      includeCompacted: false,
    );

    // retention == 0：零上下文模式，每次只携带当前用户消息
    if (chat.retention == 0) {
      final lastUser = chatMessages.lastWhere(
        (m) => m.role == 'user',
        orElse: () => chatMessages.last,
      );
      final wrapped = <ChatMessage>[];
      if (sentinel != null && sentinel.prompt.isNotEmpty) {
        wrapped.add(ChatMessage.system(sentinel.prompt));
      }
      wrapped.addAll(_convertMessages(lastUser));
      return wrapped;
    }

    // retention == -1：自动管理，返回全部消息，由调用方决定是否 compact
    final wrapped = <ChatMessage>[];
    if (sentinel != null && sentinel.prompt.isNotEmpty) {
      wrapped.add(ChatMessage.system(sentinel.prompt));
    }

    for (final msg in chatMessages) {
      wrapped.addAll(_convertMessages(msg));
    }

    return wrapped;
  }

  /// 判断是否为聊天的第一条用户消息（用于自动重命名触发）
  Future<bool> isFirstUserMessage(int chatId) async {
    final messages = await _messageRepository.getMessagesByChatId(chatId);
    return messages.where((m) => m.role == 'user').length == 1;
  }

  List<ChatMessage> _convertMessages(MessageEntity msg) {
    switch (msg.role) {
      case 'system':
        return [ChatMessage.system(msg.content)];
      case 'assistant':
        final messages = <ChatMessage>[];
        List<ToolCall>? toolCalls;
        if (msg.toolCalls.isNotEmpty) {
          final parsed = jsonDecode(msg.toolCalls) as List<dynamic>;
          toolCalls = parsed.map((tc) {
            final m = tc as Map<String, dynamic>;
            return ToolCall(
              id: m['id'] as String,
              type: 'function',
              function: FunctionCall(
                name: m['name'] as String,
                arguments: m['arguments'] as String,
              ),
            );
          }).toList();
        }
        messages.add(ChatMessage.assistant(
          content: msg.content,
          toolCalls: toolCalls,
        ));
        if (msg.toolResults.isNotEmpty) {
          final parsed = jsonDecode(msg.toolResults) as List<dynamic>;
          for (final tr in parsed) {
            final m = tr as Map<String, dynamic>;
            messages.add(ChatMessage.tool(
              toolCallId: m['id'] as String,
              content: m['result'] as String,
            ));
          }
        }
        return messages;
      default:
        if (msg.imageUrls.isNotEmpty) {
          final images = msg.imageUrls.split(',');
          final parts = <ContentPart>[ContentPart.text(msg.content)];
          for (final url in images) {
            parts.add(ContentPart.imageBase64(
              data: url,
              mediaType: 'image/jpeg',
            ));
          }
          return [ChatMessage.user(parts)];
        }
        return [ChatMessage.user(msg.content)];
    }
  }
}
