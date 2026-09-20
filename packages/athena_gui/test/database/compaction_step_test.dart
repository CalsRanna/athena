import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/database/migration/migration_202501170001_init.dart';
import 'package:athena_gui/database/migration/migration_202605210001_add_tool_fields.dart';
import 'package:athena_gui/database/migration/migration_202606240004_add_compacted_to_messages.dart';
import 'package:athena_gui/repository/sqlite_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  test(
    'SQLite stores every phase on one row and reopens completed coverage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'athena-compaction-sqlite-',
      );
      final path = '${directory.path}/test.db';
      var driver = SqliteDriver(SqliteConfig(path));
      Database.instance.laconic = Laconic(driver);
      addTearDown(() async {
        await driver.close();
        await directory.delete(recursive: true);
      });
      await Database.instance.laconic.statement(
        'CREATE TABLE migrations(name TEXT NOT NULL)',
      );
      await Migration202501170001Init().migrate();
      await Migration202605210001AddToolFields().migrate();
      await Migration202606240004AddCompactedToMessages().migrate();
      final repo = SqliteMessageRepository();
      final oldId = await repo.storeMessage(
        MessageEntity(chatId: 1, role: 'user', content: 'OLD'),
      );
      final stepId = await repo.storeMessage(
        MessageEntity(chatId: 1, role: 'assistant'),
      );
      for (final phase in [
        CompactionPhase.triggered,
        CompactionPhase.summarizing,
        CompactionPhase.persisting,
        CompactionPhase.completed,
      ]) {
        final step = CompactionStep(
          messageId: stepId,
          chatId: 1,
          runId: 42,
          phase: phase,
          startedAt: DateTime(2026),
          beforeTokens: 8000,
          messageCount: 1,
          afterTokens: phase == CompactionPhase.completed ? 800 : null,
          coveredMessageIds: [oldId],
          throughMessageId: oldId,
          summary: phase == CompactionPhase.completed ? 'SUMMARY' : '',
        );
        await repo.updateMessage(step.toMessage());
        expect(await repo.getMessagesCount(1), 2);
        final stored = (await repo.getMessageById(stepId))!;
        expect(CompactionStep.fromMessage(stored).phase, phase);
      }
      // Reopen with a fresh SQLite connection before marking originals. Coverage
      // is sufficient for replay even when this second write was interrupted.
      await driver.close();
      driver = SqliteDriver(SqliteConfig(path));
      Database.instance.laconic = Laconic(driver);
      final reopened = SqliteMessageRepository();
      final records = await reopened.getMessagesByChatId(1);
      expect(records.where((m) => m.role == 'compaction'), hasLength(1));
      expect(CompactionStep.fromMessage(records.last).afterTokens, 800);
      final replay = await ChatMessageConverter(messageRepository: reopened)
          .buildMessages(
            chat: ChatEntity(
              id: 1,
              title: 'Test',
              modelId: 1,
              sentinelId: 1,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            sentinel: null,
          );
      expect(replay, hasLength(1));
      // 压缩摘要以 user 角色注入（见 chat_message_converter：assistant 角色会让
      // DeepSeek 思考模式要求携带 reasoning_content 而 400）
      expect((replay.single as UserMessage).text, endsWith('SUMMARY'));
    },
  );
}
