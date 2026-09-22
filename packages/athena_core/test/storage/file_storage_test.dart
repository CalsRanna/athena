import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FileStorage a;
  late FileStorage b;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_fs_');
    // 两个 FileStorage 实例指向同一目录,模拟 GUI 与 TUI 各自持有的仓储
    a = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    b = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
  });

  tearDown(() => tmp.delete(recursive: true));

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  test('两个实例并发分配 id 不重复', () async {
    final ids = await Future.wait([
      for (var i = 0; i < 20; i++)
        (i.isEven ? a : b).sessionRepository.createChat(
          ChatEntity(
            title: '$i',
            modelId: 1,
            sentinelId: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ),
    ]);
    expect(ids.toSet().length, 20);
    expect(ids.reduce((x, y) => x > y ? x : y), 20);
  });

  test('provider 读穿透:另一实例的写入立即可见', () async {
    final id = await a.providerRepository.storeProvider(
      ProviderEntity(
        name: 'P',
        baseUrl: 'u',
        apiKey: '',
        enabled: false,
        isPreset: true,
        createdAt: now,
      ),
    );
    expect((await b.providerRepository.getProviderById(id))!.name, 'P');
    await b.providerRepository.updateProvider(
      (await b.providerRepository.getProviderById(id))!.copyWith(apiKey: 'k'),
    );
    expect((await a.providerRepository.getProviderById(id))!.apiKey, 'k');
    // 空 key 的模板 provider 也持久化
    await a.providerRepository.updateProvider(
      (await a.providerRepository.getProviderById(id))!.copyWith(apiKey: ''),
    );
    expect((await b.providerRepository.getAllProviders()).length, 1);
  });

  test('同一会话两个实例交错 append 与整文件重写不丢行', () async {
    final chatId = await a.sessionRepository.createChat(
      ChatEntity(
        title: 't',
        modelId: 1,
        sentinelId: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    MessageEntity msg(String c) =>
        MessageEntity(chatId: chatId, role: 'user', content: c);
    await Future.wait([
      for (var i = 0; i < 10; i++) ...[
        a.sessionRepository.storeMessage(msg('a$i')),
        b.sessionRepository.storeMessage(msg('b$i')),
        a.sessionRepository.recordUsage(chatId, 100 + i, 10),
      ],
    ]);
    final messages = await b.sessionRepository.getMessagesByChatId(chatId);
    expect(messages.length, 20);
    expect(messages.map((m) => m.id).toSet().length, 20);
    // 快照列是覆盖写:最后落盘的是某一次的值,但一定写进去了
    final chat = (await a.sessionRepository.getChatById(chatId))!;
    expect(chat.contextTokens, inInclusiveRange(100, 109));
    expect(chat.cachedTokens, 10);
  });

  test('reset 清空业务数据但保留目录缓存', () async {
    await a.sessionRepository.createChat(
      ChatEntity(
        title: 't',
        modelId: 1,
        sentinelId: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await a.catalogCacheFile.writeAsString('{}');
    expect(await a.hasData(), isTrue);
    await a.reset();
    expect(await a.hasData(), isFalse);
    expect(await a.catalogCacheFile.exists(), isTrue);
    // 计数也清零:重置后 id 从头分配
    expect(
      await a.sessionRepository.createChat(
        ChatEntity(
          title: 'n',
          modelId: 1,
          sentinelId: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      1,
    );
  });
}
