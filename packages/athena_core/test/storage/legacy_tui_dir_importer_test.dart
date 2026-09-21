import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/legacy_tui_dir_importer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FileStorage storage;
  late Directory legacy;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_tui_import_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    await storage.load();
    legacy = Directory(p.join(storage.root.path, 'tui'));
    await legacy.create(recursive: true);
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> write(String rel, String content) async {
    final f = File(p.join(legacy.path, rel));
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  String row(Map<String, dynamic> m) => '${jsonEncode(m)}\n';

  test('更早布局:chats.jsonl + messages/ + *.jsonl 列表', () async {
    await write(
      'chats.jsonl',
      row({'id': 7, 'title': 'old', 'model_id': 3, 'sentinel_id': 1,
        'created_at': 1, 'updated_at': 1}),
    );
    await write(
      'messages/7.jsonl',
      row({'id': 1, 'chat_id': 7, 'role': 'user', 'content': 'a'}) +
          row({'id': 2, 'chat_id': 7, 'role': 'assistant', 'content': 'b'}),
    );
    await write(
      'models.jsonl',
      row({'id': 3, 'name': 'm', 'model_id': 'm-1', 'provider_id': 1,
        'created_at': 1, 'updated_at': 1}),
    );
    await write('sentinels.jsonl', row({'id': 1, 'name': 'Athena', 'prompt': 'p'}));
    await write(
      'providers.jsonl',
      row({'id': 1, 'name': 'P', 'base_url': 'u', 'api_key': 'k', 'created_at': 1}),
    );

    expect(await LegacyTuiDirImporter(storage: storage).importIfNeeded(), isTrue);
    expect(await legacy.exists(), isFalse);
    expect(await Directory('${legacy.path}.migrated').exists(), isTrue);

    final chat = await storage.sessionRepository.getChatById(7);
    expect(chat!.title, 'old');
    expect(chat.modelId, 3);
    final msgs = await storage.sessionRepository.getMessagesByChatId(7);
    expect(msgs.map((m) => m.content), ['a', 'b']);
    expect((await storage.modelRepository.getModelById(3))!.modelId, 'm-1');
    expect((await storage.sentinelRepository.getSentinelById(1))!.name, 'Athena');
    expect((await storage.providerRepository.getProviderById(1))!.apiKey, 'k');

    // 第二次启动:目录已改名,跳过
    expect(await LegacyTuiDirImporter(storage: storage).importIfNeeded(), isFalse);
  });

  test('较新布局:sessions/*.jsonl + *.json 列表', () async {
    await write(
      'sessions/9.jsonl',
      row({'type': 'chat', 'id': 9, 'title': 'new', 'model_id': 1,
        'sentinel_id': 1, 'created_at': 1, 'updated_at': 1}) +
          row({'type': 'message', 'id': 1, 'chat_id': 9, 'role': 'user',
            'content': 'x'}),
    );
    await write('models.json', jsonEncode([
      {'id': 1, 'name': 'm', 'model_id': 'm-1', 'provider_id': 1,
        'created_at': 1, 'updated_at': 1},
    ]));
    await write('sentinels.json', jsonEncode([
      {'id': 1, 'name': 'Athena', 'prompt': 'p'},
    ]));

    await LegacyTuiDirImporter(storage: storage).importIfNeeded();

    expect((await storage.sessionRepository.getChatById(9))!.title, 'new');
    expect(
      (await storage.sessionRepository.getMessagesByChatId(9)).single.content,
      'x',
    );
    expect((await storage.modelRepository.getAllModels()).length, 1);
    expect((await storage.sentinelRepository.getAllSentinels()).length, 1);
  });

  test('空旧目录:只改名不报错', () async {
    expect(await LegacyTuiDirImporter(storage: storage).importIfNeeded(), isTrue);
    expect(await storage.hasData(), isFalse);
  });
}
