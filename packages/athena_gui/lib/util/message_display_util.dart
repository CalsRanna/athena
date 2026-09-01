import 'package:athena_core/entity/message_entity.dart';

/// 把消息划分为 UI 卡片，同时保留每条原始消息。
///
/// 连续的 assistant 消息共用一张外层卡片；其他角色各自占一张。卡片内部
/// 仍逐条渲染 reasoning、正文、工具和引用，不合并或过滤消息字段。
List<List<MessageEntity>> buildMessageDisplayCards(
  List<MessageEntity> messages,
) {
  final cards = <List<MessageEntity>>[];

  for (final message in messages) {
    if (message.role == 'assistant' &&
        cards.isNotEmpty &&
        cards.last.first.role == 'assistant') {
      cards.last.add(message);
    } else {
      cards.add([message]);
    }
  }

  return cards;
}
