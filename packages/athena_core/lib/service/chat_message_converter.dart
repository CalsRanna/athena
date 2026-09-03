import 'dart:convert';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// 消息格式转换与上下文组装。
///
/// 职责：将 [MessageEntity] 列表转换为 OpenAI [ChatMessage] 列表
/// （含 system prompt 注入、上下文截断、tool_calls/tool_results 展开、
/// 图片 ContentPart 处理）。不涉及网络或持久化。
class ChatMessageConverter {
  final MessageRepository _messageRepository;

  ChatMessageConverter({
    required MessageRepository messageRepository,
  }) : _messageRepository = messageRepository;

  /// 将 Entity 消息列表转换为 OpenAI ChatMessage 列表
  ///
  /// 包含上下文截断、system prompt 插入、图片处理
  Future<List<ChatMessage>> buildMessages({
    required ChatEntity chat,
    required SentinelEntity? sentinel,
    bool includeReasoning = false,
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
      wrapped.addAll(_convertMessages(lastUser, includeReasoning: includeReasoning));
      return wrapped;
    }

    // retention == -1：自动管理，返回全部消息，由调用方决定是否 compact
    final wrapped = <ChatMessage>[];
    if (sentinel != null && sentinel.prompt.isNotEmpty) {
      wrapped.add(ChatMessage.system(sentinel.prompt));
    }

    // 历史中 role=system 的消息是 compact 摘要。它们落库时被追加到
    // compact 时刻的末尾，按 id 排序读回后会夹在对话中间——system
    // 消息只在消息流头部才符合惯例，且摘要语义上替代的是被压缩的早
    // 期历史。因此归位：summary 全部放在历史区开头（sentinel 之后）。
    final summaries = <ChatMessage>[];
    final history = <ChatMessage>[];
    for (final msg in chatMessages) {
      if (msg.role == 'system') {
        summaries.addAll(
            _convertMessages(msg, includeReasoning: includeReasoning));
      } else {
        history.addAll(
            _convertMessages(msg, includeReasoning: includeReasoning));
      }
    }
    wrapped.addAll([...summaries, ...history]);

    return wrapped;
  }

  /// 判断是否为聊天的第一条用户消息（用于自动重命名触发）
  Future<bool> isFirstUserMessage(int chatId) async {
    final messages = await _messageRepository.getMessagesByChatId(chatId);
    return messages.where((m) => m.role == 'user').length == 1;
  }

  List<ChatMessage> _convertMessages(MessageEntity msg, {bool includeReasoning = false}) {
    switch (msg.role) {
      case 'system':
        return [ChatMessage.system(msg.content)];
      case 'assistant':
        final messages = <ChatMessage>[];
        // tool 结果只解析一次：既用于过滤悬空 tool_calls，也用于生成 tool
        // 消息。单条结果可达 12000 字符，而 buildMessages 每次发送都会
        // 遍历整个会话，重复 jsonDecode 的代价随会话长度线性累积。
        final toolResults = msg.toolResults.isEmpty
            ? const <dynamic>[]
            : jsonDecode(msg.toolResults) as List<dynamic>;
        final resultIds = <String>{
          for (final tr in toolResults)
            (tr as Map<String, dynamic>)['id'] as String,
        };
        List<ToolCall>? toolCalls;
        if (msg.toolCalls.isNotEmpty) {
          final parsed = jsonDecode(msg.toolCalls) as List<dynamic>;
          toolCalls = parsed
              .where((tc) => resultIds.contains((tc as Map<String, dynamic>)['id']))
              .map((tc) {
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
          // 防御：全部 tool_calls 都无对应结果时（异常取消残留），
          // 不携带 tool_calls 字段——带 tool_calls 却无 tool 响应
          // 会被 OpenAI 兼容端 400 拒绝。
          if (toolCalls.isEmpty) toolCalls = null;
        }
        final reasoning = includeReasoning && msg.reasoningContent.isNotEmpty
            ? msg.reasoningContent
            : null;
        messages.add(AssistantMessage(
          // 与 agent_service 当轮构建一致：空 content 序列化为 null，
          // 避免 "content":"" 与 tool_calls 并存被部分兼容端 400。
          content: msg.content.isEmpty ? null : msg.content,
          toolCalls: toolCalls,
          reasoningContent: reasoning,
        ));
        for (final tr in toolResults) {
          final m = tr as Map<String, dynamic>;
          messages.add(ChatMessage.tool(
            toolCallId: m['id'] as String,
            content: m['result'] as String,
          ));
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
