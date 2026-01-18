import 'package:athena/entity/chat_entity.dart';
import 'package:athena/extension/json_map_extension.dart';

/// 用于历史消息列表展示的实体
/// 包含 chat 信息和最后一条消息内容
class ChatHistoryEntity {
  final ChatEntity chat;
  final String lastMessageContent;

  ChatHistoryEntity({required this.chat, this.lastMessageContent = ''});

  factory ChatHistoryEntity.fromJson(Map<String, dynamic> json) {
    return ChatHistoryEntity(
      chat: ChatEntity.fromJson(json),
      lastMessageContent: json.getString('last_message_content'),
    );
  }
}
