import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageEntity message({
    required int id,
    required String role,
    String content = '',
  }) {
    return MessageEntity(id: id, chatId: 1, role: role, content: content);
  }

  test('连续 assistant 消息共用卡片但保留原始记录', () {
    final first = message(id: 1, role: 'assistant', content: 'first');
    final second = message(id: 2, role: 'assistant', content: 'second');

    final result = buildMessageDisplayCards([first, second]);

    expect(result, hasLength(1));
    expect(result.single, hasLength(2));
    expect(identical(result.single[0], first), isTrue);
    expect(identical(result.single[1], second), isTrue);
  });

  test('用户消息会截断 assistant 卡片', () {
    final result = buildMessageDisplayCards([
      message(id: 1, role: 'user', content: 'question 1'),
      message(id: 2, role: 'assistant', content: 'answer 1a'),
      message(id: 3, role: 'assistant', content: 'answer 1b'),
      message(id: 4, role: 'user', content: 'question 2'),
      message(id: 5, role: 'assistant', content: 'answer 2'),
    ]);

    expect(result, hasLength(4));
    expect(result.map((card) => card.first.id), [1, 2, 4, 5]);
    expect(result[1].map((message) => message.id), [2, 3]);
    expect(result[3].map((message) => message.id), [5]);
  });

  test('非 assistant 消息不会被吸收到 assistant 卡片', () {
    final result = buildMessageDisplayCards([
      message(id: 1, role: 'assistant'),
      message(id: 2, role: 'tool'),
      message(id: 3, role: 'assistant'),
    ]);

    expect(result, hasLength(3));
    expect(result.map((card) => card.single.id), [1, 2, 3]);
  });
}
