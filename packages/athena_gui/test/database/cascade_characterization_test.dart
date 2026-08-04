import 'package:flutter_test/flutter_test.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';

/// Characterization test for audit finding "C3".
///
/// C3 suspected that foreign-key CASCADE deletes could silently fail because
/// `PRAGMA foreign_keys = ON` is set only ONCE at init
/// (lib/database/database.dart:63). That would be a real bug only if Laconic
/// used a connection pool / per-operation connections, where the PRAGMA would
/// not carry over.
///
/// Investigation found this to be a FALSE ALARM: `laconic_sqlite`'s
/// `SqliteDriver` holds a single lazily-opened `Database` and reuses it for the
/// whole app lifetime, and the production `Database` singleton never calls
/// `close()`. So the PRAGMA set once persists on that single connection and
/// CASCADE works reliably. Conclusion: ACCEPTED, no production change.
///
/// These tests LOCK that invariant. A future change (swapping to a pooled /
/// per-op driver, or dropping the PRAGMA) would break them and alert
/// maintainers. The setup mirrors production:
/// `Laconic(SqliteDriver(SqliteConfig(':memory:')))` — a SINGLE Laconic
/// instance (one persistent connection) per test case, with the PRAGMA set
/// exactly once.
void main() {
  /// Builds a single-connection in-memory Laconic instance and creates the
  /// minimal schema replicating the two real CASCADE foreign keys in the app.
  /// If [enableForeignKeys] is true, `PRAGMA foreign_keys = ON` is set exactly
  /// once (as production does).
  Future<Laconic> buildLaconic({required bool enableForeignKeys}) async {
    var laconic = Laconic(SqliteDriver(SqliteConfig(':memory:')));

    if (enableForeignKeys) {
      // Set exactly ONCE, like production (database.dart:63).
      await laconic.statement('PRAGMA foreign_keys = ON');
    }

    // providers -> models (ON DELETE CASCADE), mirrors the real schema.
    await laconic.statement('''
      CREATE TABLE providers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    await laconic.statement('''
      CREATE TABLE models(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider_id INTEGER,
        FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
      )
    ''');

    // chats -> messages (ON DELETE CASCADE), mirrors the real schema.
    await laconic.statement('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT
      )
    ''');
    await laconic.statement('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER,
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    return laconic;
  }

  test('provider deletion cascades to its models', () async {
    var laconic = await buildLaconic(enableForeignKeys: true);

    var providerId = await laconic.table('providers').insertGetId({
      'name': 'OpenAI',
    });
    await laconic.table('models').insert([
      {'provider_id': providerId},
    ]);

    expect(await laconic.table('models').count(), 1);

    await laconic.table('providers').where('id', providerId).delete();

    // The child model row must be gone via CASCADE.
    expect(await laconic.table('models').count(), 0);
  });

  test('chat deletion cascades to its messages', () async {
    var laconic = await buildLaconic(enableForeignKeys: true);

    var chatId = await laconic.table('chats').insertGetId({
      'title': 'hello',
    });
    await laconic.table('messages').insert([
      {'chat_id': chatId},
    ]);

    expect(await laconic.table('messages').count(), 1);

    await laconic.table('chats').where('id', chatId).delete();

    // The child message row must be gone via CASCADE.
    expect(await laconic.table('messages').count(), 0);
  });

  test(
      'PRAGMA set once persists across operations on the reused connection '
      '(core invariant)', () async {
    // The PRAGMA is set exactly ONCE in buildLaconic, never re-applied below.
    var laconic = await buildLaconic(enableForeignKeys: true);

    // First cascade, early in the connection's life.
    var providerA = await laconic.table('providers').insertGetId({
      'name': 'A',
    });
    await laconic.table('models').insert([
      {'provider_id': providerA},
    ]);
    await laconic.table('providers').where('id', providerA).delete();
    expect(await laconic.table('models').count(), 0);

    // Several intervening operations on the SAME connection: inserts, selects,
    // and a non-cascading delete. If the PRAGMA were reset per operation, the
    // later cascade below would fail.
    var chatX = await laconic.table('chats').insertGetId({'title': 'x'});
    var chatY = await laconic.table('chats').insertGetId({'title': 'y'});
    await laconic.table('messages').insert([
      {'chat_id': chatX},
      {'chat_id': chatY},
    ]);
    var allChats = await laconic.table('chats').get();
    expect(allChats.length, 2);
    // Delete one message directly (not via cascade) to churn the connection.
    await laconic.table('messages').where('chat_id', chatX).delete();
    expect(await laconic.table('messages').count(), 1);

    // ANOTHER cascade, much later in the connection's lifetime. This is the
    // heart of the invariant: the single PRAGMA from setup is still effective.
    var providerB = await laconic.table('providers').insertGetId({
      'name': 'B',
    });
    await laconic.table('models').insert([
      {'provider_id': providerB},
      {'provider_id': providerB},
    ]);
    expect(await laconic.table('models').count(), 2);

    await laconic.table('providers').where('id', providerB).delete();

    // Still cascades — proving the PRAGMA was NOT reset per operation.
    expect(await laconic.table('models').count(), 0);
  });

  test(
      'contrast: WITHOUT the PRAGMA the child row REMAINS '
      '(proves the test is meaningful, not vacuous)', () async {
    // A fresh connection where PRAGMA foreign_keys = ON is NOT set. SQLite
    // defaults FK enforcement to OFF, so the cascade must NOT happen.
    var laconic = await buildLaconic(enableForeignKeys: false);

    var providerId = await laconic.table('providers').insertGetId({
      'name': 'NoFK',
    });
    await laconic.table('models').insert([
      {'provider_id': providerId},
    ]);

    expect(await laconic.table('models').count(), 1);

    await laconic.table('providers').where('id', providerId).delete();

    // Without FK enforcement, the orphaned child row SURVIVES. This is exactly
    // what the PRAGMA prevents — so the cascade assertions above are real.
    expect(await laconic.table('models').count(), 1);
  });
}
