import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:test/test.dart';

MessageEntity _message({
  required String id,
  required int seq,
  String role = 'user',
  String content = '',
}) => MessageEntity(
  id: id,
  seq: seq,
  chatId: 'chat',
  role: role,
  content: content,
);

/// 压缩步骤落库后的那一行（role = `compaction`）。
MessageEntity _compactionRow({
  required String id,
  required int seq,
  required CompactionPhase phase,
  List<String> coveredMessageIds = const [],
  int? throughSeq,
}) => CompactionStep(
  messageId: id,
  seq: seq,
  chatId: 'chat',
  runId: 1,
  phase: phase,
  startedAt: DateTime.now(),
  beforeTokens: 100,
  coveredMessageIds: coveredMessageIds,
  throughSeq: throughSeq,
  summary: phase == CompactionPhase.completed ? '摘要正文' : '',
).toMessage();

void main() {
  test('覆盖范围随摘要合并：二次压缩带上上一份摘要覆盖的消息', () {
    final first = _message(id: 'm1', seq: 1);
    final second = _message(id: 'm2', seq: 2);
    final previous = ConversationSummary.create(
      chatId: 'chat',
      content: '',
      coveredRecords: [first, second],
    ).copyWith(id: 's1', seq: 3);
    expect(ConversationSummary.position(previous), 2);

    final third = _message(id: 'm3', seq: 4);
    final merged = ConversationSummary.create(
      chatId: 'chat',
      content: '',
      coveredRecords: [previous, third],
    );
    // 旧摘要自身也在覆盖集合里：否则它会与合并后的摘要一起留在历史里。
    expect(ConversationSummary.coveredIds(merged), {'s1', 'm1', 'm2', 'm3'});
    expect(ConversationSummary.position(merged), 4);
  });

  test('activeHistory：摘要在它覆盖范围的末尾，尾部记录留在摘要之后', () {
    final first = _message(id: 'm1', seq: 1, content: 'one');
    final second = _message(id: 'm2', seq: 2, content: 'two');
    final row = _compactionRow(
      id: 'c1',
      seq: 4,
      phase: CompactionPhase.completed,
      coveredMessageIds: ['m1', 'm2'],
      throughSeq: 2,
    );
    final tail = _message(id: 'm3', seq: 5, content: 'three');

    final active = ConversationSummary.activeHistory([
      first,
      second,
      row,
      tail,
    ]);
    expect(active.map((m) => m.id), ['c1', 'm3']);
    expect(ConversationSummary.position(row), 2);
  });

  test('未完成的压缩行不算摘要，也不进入历史', () {
    final failed = _compactionRow(
      id: 'c1',
      seq: 2,
      phase: CompactionPhase.failed,
      coveredMessageIds: ['m1'],
      throughSeq: 1,
    );
    final kept = _message(id: 'm1', seq: 1, content: 'one');

    expect(ConversationSummary.isSummary(failed), isFalse);
    expect(ConversationSummary.activeHistory([kept, failed]).map((m) => m.id), [
      'm1',
    ]);
  });
}
