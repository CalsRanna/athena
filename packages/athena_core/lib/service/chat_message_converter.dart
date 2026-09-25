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
        final hasContent = msg.content.trim().isNotEmpty;
        // 空载荷记录整批丢弃：不产出
        // `AssistantMessage(content: null, tool_calls: null)`。
        //
        // 这类记录没有正文、也没有能被接受的 tool_calls，唯一来源是"没走完
        // 收尾流程"的迭代占位：进程被强杀 / 崩溃 / 断电（取消、错误、正常
        // 结束都会写入文本），或思考模式下只输出 reasoning 就被截断。
        // OpenAI 兼容端对空 assistant 一律 400（DeepSeek 报
        // `Invalid assistant message: content or tool_calls must be set`），
        // 而它只要留在历史里，该会话**此后每次请求都被拒**——用户看到的就是
        // "中断后再也继续不了"。丢弃它是安全的：没有正文可失去，其
        // toolResults（如果有）同样没有归属，必须一并丢弃，否则会变成没有
        // 前置 tool_calls 的孤立 tool 消息，那是另一种 400。
        if (!hasContent && toolCalls == null) return const [];
        final reasoning = includeReasoning && msg.reasoningContent.isNotEmpty
            ? msg.reasoningContent
            : null;
        messages.add(
          AssistantMessage(
            // 与 agent_service 当轮构建一致：空 content 序列化为 null，
            // 避免 "content":"" 与 tool_calls 并存被部分兼容端 400。
            content: hasContent ? msg.content : null,
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
          // 仅图片的消息不带空 text part：Messages 协议要求 text block 非空。
          final parts = <ContentPart>[
            if (msg.content.isNotEmpty) ContentPart.text(msg.content),
          ];
          for (final data in images) {
            parts.add(
              ContentPart.imageBase64(
                data: data,
                mediaType: sniffImageMediaType(data),
              ),
            );
          }
          return [ChatMessage.user(parts)];
        }
        return [ChatMessage.user(msg.content)];
    }
  }
}

/// 按文件头识别 base64 图片的媒体类型。
///
/// 客户端存的是原始文件字节（粘贴的截图多为 PNG），而 Messages 协议会校验
/// 声明的媒体类型与实际内容是否一致，不一致直接 400；识别不出时沿用 JPEG。
String sniffImageMediaType(String base64Data) {
  final List<int> head;
  try {
    // 16 个 base64 字符解出 12 字节，足够覆盖下面所有签名。
    final prefix = base64Data.length > 16
        ? base64Data.substring(0, 16)
        : base64Data;
    head = base64Decode(prefix);
  } on FormatException {
    return 'image/jpeg';
  }
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (head.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (head[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
