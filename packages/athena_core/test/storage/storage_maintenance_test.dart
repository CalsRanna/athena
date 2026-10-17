import 'dart:io';

import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_maintenance.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late FileStorage storage;
  late StorageMaintenance maintenance;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_storage_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.load();
    maintenance = StorageMaintenance(storage);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<String> createChatWithSnapshot() async {
    final chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 'Storage',
        modelId: 'model',
        sentinelId: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final target = await storage.sessionRepository.storeMessage(
      MessageEntity(chatId: chatId, role: 'user', content: 'A'),
    );
    await storage.sessionRepository.rewindToUserMessage(chatId, target.id!);
    return chatId;
  }

  test('measure separates snapshots and tool outputs', () async {
    await createChatWithSnapshot();
    await ToolOutputStore(directory: storage.toolOutputsDir).save('x' * 100);

    final usage = await maintenance.measure();

    expect(usage.rewindSnapshotCount, 1);
    expect(usage.toolOutputCount, 1);
    expect(usage.rewindSnapshotBytes, greaterThan(0));
    expect(usage.toolOutputBytes, greaterThan(0));
  });

  test('cleanup removes only the files it owns', () async {
    final chatId = await createChatWithSnapshot();
    await ToolOutputStore(directory: storage.toolOutputsDir).save('x' * 100);
    final keep = File(p.join(storage.toolOutputsDir.path, 'notes.txt'));
    await keep.writeAsString('keep me');

    expect(await maintenance.clearRewindSnapshots(), 1);
    expect(await maintenance.clearToolOutputs(), 1);
    expect(await storage.sessionRepository.getChatById(chatId), isNotNull);
    expect(
      await storage.toolOutputsDir
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.txt'))
          .toList(),
      hasLength(1),
    );
    expect(await keep.readAsString(), 'keep me');
    expect((await maintenance.measure()).rewindSnapshotCount, 0);
    expect((await maintenance.measure()).toolOutputCount, 0);
    expect(await maintenance.clearRewindSnapshots(), 0);
    expect(await maintenance.clearToolOutputs(), 0);
  });

  test(
    'cleanup removes snapshots whose session file is already gone',
    () async {
      final chatId = await createChatWithSnapshot();
      await File(p.join(storage.sessionsDir.path, '$chatId.jsonl')).delete();

      expect(await maintenance.clearRewindSnapshots(), 1);
      expect((await maintenance.measure()).rewindSnapshotCount, 0);
    },
  );
}
