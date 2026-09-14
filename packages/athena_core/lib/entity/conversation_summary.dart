import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';

/// Summary coverage is stored with the summary so replay stays consistent even
/// if marking the original records is interrupted. Originals remain recoverable.
class ConversationSummary {
  static bool isSummary(MessageEntity message) =>
      message.role == 'summary' ||
      message.role == 'system' ||
      (message.role == 'compaction' &&
          CompactionStep.fromMessage(message).phase ==
              CompactionPhase.completed);

  static Set<int> coveredIds(MessageEntity message) {
    if (message.role != 'summary' && message.role != 'compaction') return {};
    final metadata = jsonDecode(message.reference) as Map<String, dynamic>;
    return (metadata['coveredMessageIds'] as List<dynamic>).cast<int>().toSet();
  }

  static int position(MessageEntity message) {
    // Legacy system summaries precede all retained history.
    if (message.role == 'system') return -1;
    if (!isSummary(message)) return message.id ?? 0;
    final metadata = jsonDecode(message.reference) as Map<String, dynamic>;
    return metadata['throughMessageId'] as int;
  }

  static List<MessageEntity> activeHistory(List<MessageEntity> records) {
    final covered = <int>{
      for (final message in records)
        if (!message.compacted && isSummary(message)) ...coveredIds(message),
    };
    return records
        .where(
          (m) =>
              !m.compacted &&
              !covered.contains(m.id) &&
              (m.role != 'compaction' || isSummary(m)),
        )
        .toList()
      ..sort((a, b) {
        final byPosition = position(a).compareTo(position(b));
        return byPosition != 0 ? byPosition : (a.id ?? 0).compareTo(b.id ?? 0);
      });
  }

  static MessageEntity create({
    required int chatId,
    required String content,
    required List<MessageEntity> coveredRecords,
  }) {
    final ids = <int>{
      for (final message in coveredRecords) ...[
        message.id!,
        if (isSummary(message)) ...coveredIds(message),
      ],
    }.toList()..sort();
    final positions = coveredRecords.map(position).toList()..sort();
    return MessageEntity(
      chatId: chatId,
      role: 'summary',
      content: content,
      reference: jsonEncode({
        'coveredMessageIds': ids,
        'throughMessageId': positions.last,
      }),
    );
  }
}
