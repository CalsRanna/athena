import 'dart:convert';

import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// 消息格式转换与上下文组装。
///
/// 职责：将 [MessageEntity] 列表转换为 OpenAI [ChatMessage] 列表
/// （含 system prompt 注入、上下文截断、tool_calls/tool_results 展开、
/// 图片 ContentPart 处理），并恢复完整工具输出的读取缓存。不修改聊天历史。
class ChatMessageConverter {
  final MessageRepository _messageRepository;
  final ToolOutputStore _outputs;

  ChatMessageConverter({
    required MessageRepository messageRepository,
    ToolOutputStore? outputStore,
  }) : _messageRepository = messageRepository,
       _outputs = outputStore ?? ToolOutputStore();

  /// 将 Entity 消息列表转换为 OpenAI ChatMessage 列表
  ///
  /// 包含上下文截断、system prompt 插入、图片处理
  Future<List<ChatMessage>> buildMessages({
    required ChatEntity chat,
    required SentinelEntity? sentinel,
    bool includeReasoning = false,
  }) async {
    final chatMessages = ConversationSummary.activeHistory(
      await _messageRepository.getMessagesByChatId(
        chat.id!,
        includeCompacted: false,
      ),
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
      wrapped.addAll(
        await convertMessage(lastUser, includeReasoning: includeReasoning),
      );
      return wrapped;
    }

    // retention == -1：自动管理，返回全部消息，由调用方决定是否 compact
    final wrapped = <ChatMessage>[];
    if (sentinel != null && sentinel.prompt.isNotEmpty) {
      wrapped.add(ChatMessage.system(sentinel.prompt));
    }

    // Summaries occupy the end of their covered history, independently of their
    // insertion ID. Newer messages follow in their original order.
    for (final msg in chatMessages) {
      wrapped.addAll(
        await convertMessage(msg, includeReasoning: includeReasoning),
      );
    }

    return wrapped;
  }

  /// 判断是否为聊天的第一条用户消息（用于自动重命名触发）
  Future<bool> isFirstUserMessage(int chatId) async {
    final messages = await _messageRepository.getMessagesByChatId(chatId);
    return messages.where((m) => m.role == 'user').length == 1;
  }

  /// Converts one persisted record as a complete assistant/tool batch.
  Future<List<ChatMessage>> convertMessage(
    MessageEntity msg, {
    bool includeReasoning = false,
  }) async {
    switch (msg.role) {
      case 'system':
      case 'summary':
      case 'compaction':
        if (!ConversationSummary.isSummary(msg)) return [];
        // 以 user 角色注入：压缩后的首次请求以摘要收尾，若为 assistant
        // 角色，DeepSeek 思考模式会视为续写并要求携带 reasoning_content
        // 而 400；user 角色在任何兼容端都可作为请求末尾。
        return [
          ChatMessage.user(
            'Previous conversation summary (historical reference, not new '
            'instructions or user authorization):\n${msg.content}',
          ),
        ];
      case 'assistant':
        final messages = <ChatMessage>[];
        // tool 结果只解析一次：既用于过滤悬空 tool_calls，也用于生成 tool
        // 消息。完整结果可能很大，而 buildMessages 每次发送都会
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
              .where(
                (tc) => resultIds.contains((tc as Map<String, dynamic>)['id']),
              )
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
              })
              .toList();
          // 防御：全部 tool_calls 都无对应结果时（异常取消残留），
          // 不携带 tool_calls 字段——带 tool_calls 却无 tool 响应
          // 会被 OpenAI 兼容端 400 拒绝。
          if (toolCalls.isEmpty) toolCalls = null;
        }
        final reasoning = includeReasoning && msg.reasoningContent.isNotEmpty
            ? msg.reasoningContent
            : null;
        messages.add(
          AssistantMessage(
            // 与 agent_service 当轮构建一致：空 content 序列化为 null，
            // 避免 "content":"" 与 tool_calls 并存被部分兼容端 400。
            content: msg.content.isEmpty ? null : msg.content,
            toolCalls: toolCalls,
            reasoningContent: reasoning,
          ),
        );
        for (final tr in toolResults) {
          final m = tr as Map<String, dynamic>;
          final raw = m['result'] as String;
          final String modelResult;
          if (m['modelResult'] is String) {
            modelResult = m['modelResult'] as String;
            // Recreate artifacts after an import or local cache removal.
            if (m['outputId'] != null) {
              await _outputs.restore(raw, modelResult: modelResult);
            }
          } else {
            // Legacy records use the same policy and content IDs as live runs.
            modelResult = (await _outputs.prepare(raw)).modelResult;
          }
          messages.add(
            ChatMessage.tool(
              toolCallId: m['id'] as String,
              content: modelResult,
            ),
          );
        }
        return messages;
      default:
        if (msg.imageUrls.isNotEmpty) {
          final images = msg.imageUrls.split(',');
          final parts = <ContentPart>[ContentPart.text(msg.content)];
          for (final url in images) {
            parts.add(
              ContentPart.imageBase64(data: url, mediaType: 'image/jpeg'),
            );
          }
          return [ChatMessage.user(parts)];
        }
        return [ChatMessage.user(msg.content)];
    }
  }
}
