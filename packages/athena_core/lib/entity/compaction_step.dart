import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';

enum CompactionPhase {
  triggered,
  summarizing,
  persisting,
  completed,
  failed,
  cancelled,
}

/// One durable execution step. Every phase updates the same message ID.
/// Completed content is also the summary; display metadata never enters the LLM.
class CompactionStep {
  const CompactionStep({
    required this.messageId,
    required this.chatId,
    required this.runId,
    required this.phase,
    required this.startedAt,
    required this.beforeTokens,
    this.finishedAt,
    this.afterTokens,
    this.messageCount = 0,
    this.coveredMessageIds = const [],
    this.throughMessageId,
    this.summary = '',
    this.error,
  });

  final int messageId;
  final int chatId;
  final int runId;
  final CompactionPhase phase;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int beforeTokens;
  final int? afterTokens;
  final int messageCount;
  final List<int> coveredMessageIds;
  final int? throughMessageId;
  final String summary;
  final String? error;

  String get compactionId => '$chatId:$messageId';
  bool get isTerminal => switch (phase) {
    CompactionPhase.completed ||
    CompactionPhase.failed ||
    CompactionPhase.cancelled => true,
    _ => false,
  };

  CompactionStep copyWith({
    CompactionPhase? phase,
    DateTime? finishedAt,
    int? afterTokens,
    int? messageCount,
    List<int>? coveredMessageIds,
    int? throughMessageId,
    String? summary,
    String? error,
  }) => CompactionStep(
    messageId: messageId,
    chatId: chatId,
    runId: runId,
    phase: phase ?? this.phase,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    beforeTokens: beforeTokens,
    afterTokens: afterTokens ?? this.afterTokens,
    messageCount: messageCount ?? this.messageCount,
    coveredMessageIds: coveredMessageIds ?? this.coveredMessageIds,
    throughMessageId: throughMessageId ?? this.throughMessageId,
    summary: summary ?? this.summary,
    error: error ?? this.error,
  );

  MessageEntity toMessage() => MessageEntity(
    id: messageId,
    chatId: chatId,
    role: 'compaction',
    content: summary,
    reference: jsonEncode({
      'compactionId': compactionId,
      'runId': runId,
      'phase': phase.name,
      'startedAt': startedAt.toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      'beforeTokens': beforeTokens,
      if (afterTokens != null) 'afterTokens': afterTokens,
      'messageCount': messageCount,
      'coveredMessageIds': coveredMessageIds,
      if (throughMessageId != null) 'throughMessageId': throughMessageId,
      if (error != null) 'error': error,
    }),
  );

  factory CompactionStep.fromMessage(MessageEntity message) {
    final data = jsonDecode(message.reference) as Map<String, dynamic>;
    return CompactionStep(
      messageId: message.id!,
      chatId: message.chatId,
      runId: data['runId'] as int,
      phase: CompactionPhase.values.byName(data['phase'] as String),
      startedAt: DateTime.parse(data['startedAt'] as String),
      finishedAt: data['finishedAt'] == null
          ? null
          : DateTime.parse(data['finishedAt'] as String),
      beforeTokens: data['beforeTokens'] as int,
      afterTokens: data['afterTokens'] as int?,
      messageCount: data['messageCount'] as int,
      coveredMessageIds: (data['coveredMessageIds'] as List<dynamic>)
          .cast<int>(),
      throughMessageId: data['throughMessageId'] as int?,
      summary: message.content,
      error: data['error'] as String?,
    );
  }
}
