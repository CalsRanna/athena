import 'package:athena_core/entity/chat_entity.dart';
import 'package:test/test.dart';

void main() {
  ChatEntity chat(int sentinelId) => ChatEntity(
    title: 'test',
    modelId: 1,
    sentinelId: sentinelId,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );

  test('sentinelId 0 explicitly means no Sentinel', () {
    expect(chat(ChatEntity.noSentinelId).hasSentinel, isFalse);
    expect(chat(1).hasSentinel, isTrue);
  });
}
