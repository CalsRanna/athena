import 'package:flutter_test/flutter_test.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';

/// Locks the stable-ordering contract for
/// [TRPGMessageRepository.getMessagesByGameId].
///
/// `created_at` is a millisecond timestamp; messages created within the same
/// millisecond have an undefined order when ordered by `created_at` alone.
/// The repository orders by `created_at ASC, id ASC` so that ties on
/// `created_at` fall back to insertion order (the autoincrement `id`).
///
/// This test builds its own in-memory Laconic instance and runs the SAME query
/// shape the repository uses, since the production method reads from the
/// `Database.instance.laconic` singleton which is not substitutable in a unit
/// test.
void main() {
  late Laconic laconic;

  setUp(() async {
    laconic = Laconic(SqliteDriver(SqliteConfig(':memory:')));
    await laconic.statement('''
      CREATE TABLE trpg_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  });

  Future<List<int>> queryIds(int gameId) async {
    var results = await laconic
        .table('trpg_messages')
        .where('game_id', gameId)
        .orderBy('created_at', direction: 'asc')
        .orderBy('id', direction: 'asc')
        .get();
    return results.map((r) => r.toMap()['id'] as int).toList();
  }

  test('rows sharing the same created_at come back in insertion (id) order',
      () async {
    const gameId = 1;
    const sameMs = 1700000000000;

    // Insert several rows for one game sharing the SAME millisecond, in a
    // known insertion order. ids are assigned 1, 2, 3, 4 by AUTOINCREMENT.
    for (var i = 0; i < 4; i++) {
      await laconic.table('trpg_messages').insert([
        {'game_id': gameId, 'created_at': sameMs},
      ]);
    }

    var ids = await queryIds(gameId);

    // Despite identical created_at, order is the stable autoincrement id.
    expect(ids, [1, 2, 3, 4]);
  });

  test('created_at remains the primary sort; id only breaks ties', () async {
    const gameId = 7;
    const earlier = 1700000000000;
    const later = 1700000000001;

    // Insert a "later" row FIRST (lower id, higher created_at), then two
    // "earlier" rows sharing the same created_at. If id were the primary key
    // the later row would sort first; it must sort last.
    await laconic.table('trpg_messages').insert([
      {'game_id': gameId, 'created_at': later}, // id = 1
    ]);
    await laconic.table('trpg_messages').insert([
      {'game_id': gameId, 'created_at': earlier}, // id = 2
    ]);
    await laconic.table('trpg_messages').insert([
      {'game_id': gameId, 'created_at': earlier}, // id = 3
    ]);

    var ids = await queryIds(gameId);

    // earlier rows first (ids 2,3 in insertion order), later row (id 1) last.
    expect(ids, [2, 3, 1]);
  });

  test('only matching game_id rows are returned', () async {
    await laconic.table('trpg_messages').insert([
      {'game_id': 1, 'created_at': 1700000000000}, // id = 1
    ]);
    await laconic.table('trpg_messages').insert([
      {'game_id': 2, 'created_at': 1700000000000}, // id = 2
    ]);
    await laconic.table('trpg_messages').insert([
      {'game_id': 1, 'created_at': 1700000000000}, // id = 3
    ]);

    var ids = await queryIds(1);

    expect(ids, [1, 3]);
  });
}
