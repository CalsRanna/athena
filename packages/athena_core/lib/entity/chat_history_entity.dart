import 'package:athena_core/entity/chat_entity.dart';

/// 会话列表项的**展示投影**：`ChatEntity` + 最后一条消息内容。
///
/// **不是持久化实体**——它不落盘，由 `ChatRepository.getAllChatsWithLastMessage()`
/// 从会话与其消息即时拼出，只喂给前端的会话列表（GUI 与 TUI 各持一份它的
/// signal）。故不实现序列化：它没有自己的存储形态。
class ChatHistoryEntity {
  final ChatEntity chat;
  final String lastMessageContent;

  const ChatHistoryEntity({required this.chat, this.lastMessageContent = ''});
}
