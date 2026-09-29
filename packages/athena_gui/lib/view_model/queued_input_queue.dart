import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:signals/signals.dart';

/// 一条已交给 run、但还没轮到自己发出去的输入。
class QueuedChatInput {
  final MessageEntity message;
  final ChatEntity chat;
  final bool jsonMode;

  const QueuedChatInput(this.message, this.chat, this.jsonMode);
}

/// 待发输入的排队区：按会话分开，先进先出。
///
/// 排队只在「该会话已有 run 在跑」时发生（见 `ChatViewModel.sendMessage`）：
/// 用户在 run 进行中又发了一条，这条输入不能直接进会话历史——否则它会在上一轮
/// 还没结束时就被写进模型上下文。UI 在 composer 上方显示当前会话的排队项。
///
/// **去重与移除都按对象标识，不按内容。** 同一个对象排两次只留一条；内容相同的
/// 两条是两条不同的输入（用户确实发了两次），必须都留着。调用方拿回同一个对象
/// 问「它还在队里吗」也正是靠这一点。
class QueuedInputQueue {
  final _inputs = listSignal<QueuedChatInput>([]);

  List<QueuedChatInput> get all => _inputs.value;

  bool get isEmpty => _inputs.value.isEmpty;

  /// 属于 [chatId] 的排队项对应的消息，按排队顺序——composer 上方展示的就是它。
  List<MessageEntity> messagesFor(String? chatId) => [
    for (final input in _inputs.value)
      if (input.chat.id == chatId) input.message,
  ];

  void enqueue(QueuedChatInput input) {
    if (contains(input)) return;
    _inputs.value = [..._inputs.value, input];
  }

  bool contains(QueuedChatInput input) => _inputs.value.contains(input);

  /// 该会话最早排队的输入；没有就是 null。
  QueuedChatInput? nextFor(String chatId) =>
      _inputs.value.where((input) => input.chat.id == chatId).firstOrNull;

  void remove(QueuedChatInput input) {
    if (!contains(input)) return;
    _inputs.value = _inputs.value
        .where((queued) => !identical(queued, input))
        .toList();
  }

  void clear() {
    _inputs.value = [];
  }

  /// 丢掉这些会话的全部排队项（会话被删掉时用）。
  void discardChats(Set<String> chatIds) {
    _inputs.value = _inputs.value
        .where((input) => !chatIds.contains(input.chat.id))
        .toList();
  }
}
