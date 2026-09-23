import 'package:athena_core/entity/message_entity.dart';

/// 会话里的一轮：一条用户消息 + 它之后的第一条有正文的 agent 回答。
///
/// 这是**展示口径**上的"一轮"，与消息 sliver 的分组规则一致（一轮 = 一条用户
/// 消息 + 它之后的所有助手消息），助手卡内的推理 / 工具步骤都不单独成轮。
class ChatTurn {
  /// 这一轮的起点：用户消息。
  final MessageEntity user;

  /// 该轮 agent 的回答正文；这一轮还没收尾（仍在跑）时为空串。
  final String answer;

  const ChatTurn({required this.user, this.answer = ''});

  bool get hasAnswer => answer.isNotEmpty;

  /// 这一轮的标识：用户消息 id（缺 id 的新消息回退到对象身份）。
  Object get id => user.id ?? identityHashCode(user);
}

/// 把消息列表切成轮次。
///
/// 规则与 `MessageRepository.getOpeningAnswerPreview` 一致：回答取用户消息
/// **之后第一条有正文的 assistant 消息**，跳过空占位行与 reasoning 行；
/// compaction 消息不算回答。
///
/// 传入的通常只是**已加载**的窗口（消息列表是窗口化分页的），所以历史被压缩
/// 或尚未翻页时，前面可能缺少用户消息——那些助手消息不成轮，直接略过。
List<ChatTurn> buildChatTurns(List<MessageEntity> messages) {
  final turns = <ChatTurn>[];
  MessageEntity? pendingUser;
  var answer = '';

  void flush() {
    final user = pendingUser;
    if (user != null) turns.add(ChatTurn(user: user, answer: answer));
    pendingUser = null;
    answer = '';
  }

  for (final message in messages) {
    if (message.role == 'user') {
      flush();
      pendingUser = message;
      continue;
    }
    if (pendingUser == null || answer.isNotEmpty) continue;
    final content = message.content.trim();
    if (message.role == 'assistant' && content.isNotEmpty) {
      answer = content;
    }
  }
  flush();
  return turns;
}
