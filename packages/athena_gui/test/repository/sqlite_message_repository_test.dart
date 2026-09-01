import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/repository/sqlite_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';

void main() {
  late Laconic laconic;
  late SqliteMessageRepository repository;

  setUp(() async {
    laconic = Laconic(SqliteDriver(SqliteConfig(':memory:')));
    Database.instance.laconic = laconic;
    await laconic.statement('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        reasoning_content TEXT DEFAULT '',
        reasoning INTEGER DEFAULT 0,
        expanded INTEGER DEFAULT 0,
        image_urls TEXT DEFAULT '',
        reference TEXT DEFAULT '',
        tool_calls TEXT DEFAULT '',
        tool_results TEXT DEFAULT '',
        compacted INTEGER DEFAULT 0,
        reasoning_started_at INTEGER NOT NULL,
        reasoning_updated_at INTEGER NOT NULL
      )
    ''');
    repository = SqliteMessageRepository();
  });

  tearDown(() => laconic.close());

  test('最近消息分页按会话和 beforeId 游标返回升序结果', () async {
    for (var index = 1; index <= 6; index++) {
      await repository.storeMessage(
        MessageEntity(chatId: 1, role: 'user', content: 'message $index'),
      );
      if (index <= 2) {
        await repository.storeMessage(
          MessageEntity(chatId: 2, role: 'user', content: 'other $index'),
        );
      }
    }

    final recent = await repository.loadRecentMessages(1, count: 3);
    expect(recent.map((message) => message.content), [
      'message 4',
      'message 5',
      'message 6',
    ]);
    final recentIds = recent.map((message) => message.id!).toList();
    expect(recentIds, orderedEquals([...recentIds]..sort()));

    final older = await repository.loadRecentMessages(
      1,
      count: 3,
      beforeId: recent.first.id,
    );
    expect(older.map((message) => message.content), [
      'message 1',
      'message 2',
      'message 3',
    ]);
  });
}
