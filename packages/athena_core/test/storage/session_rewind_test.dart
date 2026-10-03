import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/session_jsonl_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late FileStorage storage;
  late String chatId;
  late JsonlSessionRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_rewind_');
    storage = FileStorage(root: temp);
    repo = storage.sessionRepository;
    chatId = await repo.createChat(
      ChatEntity(
        title: 'Rewind',
        modelId: 'model',
        sentinelId: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });
  tearDown(() => temp.delete(recursive: true));

  Future<MessageEntity> append(String role, String content) =>
      repo.storeMessage(
        MessageEntity(chatId: chatId, role: role, content: content),
      );
  File getSession() => File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));

  test(
    'rewind cuts the entire persisted suffix and preserves exact snapshot bytes',
    () async {
      final first = await append('user', 'A');
      await append('assistant', 'answer A');
      final target = await repo.storeMessage(
        MessageEntity(
          chatId: chatId,
          role: 'user',
          content: 'B',
          imageUrls: base64Encode([1, 2, 3]),
        ),
      );
      await append('assistant', 'answer B');
      // A later record absent from a front-end message window must also disappear.
      await append('user', 'C');
      final original = await getSession().readAsBytes();
      await repo.recordUsage(chatId, 123, 45);
      final snapshotBytes = await getSession().readAsBytes();
      final lease = await repo.acquireSessionActivity(chatId);
      final result = await repo.rewindToUserMessage(chatId, target.id!);
      await lease.release();
      expect(result.input.content, 'B');
      expect(result.input.imageUrls, target.imageUrls);
      expect(result.turnStartIds, [first.id]);
      expect((await repo.getMessagesByChatId(chatId)).map((m) => m.content), [
        'A',
        'answer A',
      ]);
      expect(await File(result.snapshotPath).readAsBytes(), snapshotBytes);
      expect(original, isNot(snapshotBytes));
      expect(await repo.getChatsCount(), 1);
      expect(result.chat.contextTokens, -1);
      expect(result.chat.cachedTokens, -1);
      expect(result.chat.rewoundAt, isNotNull);
      final resent = await append('user', result.input.content);
      expect(resent.id, isNot(target.id));
    },
  );

  test(
    'removing nested compactions restores original prefix and excludes withdrawn instructions',
    () async {
      final a = await append('user', 'keep A');
      final answer = await append('assistant', 'keep answer');
      final b = await append('user', 'withdraw B');
      final summary1 = await repo.storeMessage(
        ConversationSummary.create(
          chatId: chatId,
          content: 'summary mentioning B',
          coveredRecords: [a, answer, b],
        ),
      );
      await repo.markAsCompacted(chatId, {a.id!, answer.id!, b.id!});
      final c = await append('user', 'withdraw C');
      final summary2 = await repo.storeMessage(
        ConversationSummary.create(
          chatId: chatId,
          content: 'nested summary',
          coveredRecords: [summary1, c],
        ),
      );
      await repo.markAsCompacted(chatId, {summary1.id!, c.id!});
      await append('assistant', summary2.content);
      final lease = await repo.acquireSessionActivity(chatId);
      await repo.rewindToUserMessage(chatId, b.id!);
      await lease.release();
      final records = await repo.getMessagesByChatId(chatId);
      expect(records.every((m) => !m.compacted), isTrue);
      expect(ConversationSummary.activeHistory(records).map((m) => m.content), [
        'keep A',
        'keep answer',
      ]);
    },
  );

  test(
    'valid earlier completed compaction retains coverage after a later compaction is removed',
    () async {
      final a = await append('user', 'A');
      final answer = await append('assistant', 'answer A');
      final summary = await repo.storeMessage(
        CompactionStep(
          messageId: 'placeholder',
          seq: 0,
          chatId: chatId,
          runId: 1,
          phase: CompactionPhase.completed,
          startedAt: DateTime(2026),
          beforeTokens: 1000,
          afterTokens: 100,
          summary: 'summary A',
          coveredMessageIds: [a.id!, answer.id!],
          throughSeq: answer.seq,
        ).toMessage(),
      );
      final b = await append('user', 'B');
      final later = await repo.storeMessage(
        ConversationSummary.create(
          chatId: chatId,
          content: 'summary B',
          coveredRecords: [summary, b],
        ),
      );
      await repo.markAsCompacted(chatId, {
        a.id!,
        answer.id!,
        summary.id!,
        b.id!,
      });
      expect(later.id, isNotNull);
      final lease = await repo.acquireSessionActivity(chatId);
      await repo.rewindToUserMessage(chatId, b.id!);
      await lease.release();
      final records = await repo.getMessagesByChatId(chatId);
      expect(
        records.where((m) => m.id == summary.id).single.compacted,
        isFalse,
      );
      expect(records.where((m) => m.id == a.id).single.compacted, isTrue);
      expect(ConversationSummary.activeHistory(records).map((m) => m.content), [
        'summary A',
      ]);
    },
  );

  test(
    'legacy summaries without provenance fail explicitly and preserve history',
    () async {
      await append('system', 'legacy summary');
      final target = await append('user', 'A');
      final original = await getSession().readAsBytes();
      await expectLater(
        repo.rewindToUserMessage(chatId, target.id!),
        throwsUnsupportedError,
      );
      expect(await getSession().readAsBytes(), original);
    },
  );

  test('invalid targets leave bytes and metadata unchanged', () async {
    final assistant = await append('assistant', 'answer');
    final original = await getSession().readAsBytes();
    for (final id in ['missing', assistant.id!]) {
      await expectLater(
        repo.rewindToUserMessage(chatId, id),
        throwsArgumentError,
      );
    }
    expect(await getSession().readAsBytes(), original);
    expect((await storage.sessionsDir.list().toList()).length, 1);
  });

  test('snapshot write failure leaves the original session intact', () async {
    final target = await append('user', 'A');
    final original = await getSession().readAsBytes();
    final store = SessionJsonlStore(
      file: getSession(),
      locks: storage.locks,
      idGenerator: const _FixedIdGenerator(),
    );
    await Directory('${getSession().path}.rewind-fixed').create();
    await expectLater(
      store.rewindToUserMessage(target.id!),
      throwsA(isA<FileSystemException>()),
    );
    expect(await getSession().readAsBytes(), original);
  });

  test(
    'stale chat updates preserve the rewind cutoff and invalidate usage',
    () async {
      final stale = (await repo.getChatById(chatId))!;
      final target = await append('user', 'A');
      final lease = await repo.acquireSessionActivity(chatId);
      final result = await repo.rewindToUserMessage(chatId, target.id!);
      await lease.release();
      await repo.updateChat(stale.copyWith(title: 'renamed'));
      final current = (await repo.getChatById(chatId))!;
      expect(current.rewoundAt, result.chat.rewoundAt);
      expect(current.contextTokens, -1);
      expect(current.title, 'renamed');
    },
  );

  test(
    'session activity excludes another repository instance and is released idempotently',
    () async {
      final other = JsonlSessionRepository(
        sessionsDir: storage.sessionsDir,
        locks: storage.locks,
      );
      final lease = await repo.acquireSessionActivity(chatId);
      await expectLater(other.acquireSessionActivity(chatId), throwsStateError);
      await lease.release();
      await lease.release();
      await (await other.acquireSessionActivity(chatId)).release();
    },
  );

  test('session activity excludes a writer in another process', () async {
    final script = File(p.join(temp.path, 'hold_lock.dart'));
    await script.writeAsString('''
import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> args) async {
  final file = File(args.single);
  await file.parent.create(recursive: true);
  final handle = await file.open(mode: FileMode.append);
  await handle.lock(FileLock.exclusive);
  stdout.writeln('locked');
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  await handle.close();
}
''');
    final lock = storage.locks.named('session-activity/$chatId.jsonl');
    final process = await Process.start(Platform.resolvedExecutable, [
      '--disable-dart-dev',
      script.path,
      lock.path,
    ]);
    try {
      expect(
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 10)),
        'locked',
      );
      await expectLater(repo.acquireSessionActivity(chatId), throwsStateError);
    } finally {
      process.stdin.writeln('release');
      await process.stdin.close();
      expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
    }
    await (await repo.acquireSessionActivity(chatId)).release();
  });
}

class _FixedIdGenerator extends IdGenerator {
  const _FixedIdGenerator();
  @override
  String next() => 'fixed';
}
