import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 数据文件损坏、计数丢失、多实例并发时，已有数据不能被静默覆盖或丢失。
void main() {
  late Directory tmp;
  late FileStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_integrity_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
  });

  tearDown(() => tmp.delete(recursive: true));

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Future<String> createChat(String title) =>
      storage.sessionRepository.createChat(
        ChatEntity(
          title: title,
          modelId: '1',
          sentinelId: '1',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<MessageEntity> addMessage(String chatId, String content) =>
      storage.sessionRepository.storeMessage(
        MessageEntity(chatId: chatId, role: 'user', content: content),
      );

  File sessionFile(String chatId) =>
      File(p.join(storage.sessionsDir.path, '$chatId.jsonl'));

  List<File> backupsOf(File file) => file.parent
      .listSync()
      .whereType<File>()
      .where(
        (f) =>
            p.basename(f.path).startsWith('${p.basename(file.path)}.corrupt-'),
      )
      .toList();

  group('会话文件', () {
    test('截在多字节字符中间的半行不影响会话列表，之后的追加也不丢', () async {
      final chatId = await createChat('中文会话');
      await addMessage(chatId, '第一条');
      // 模拟追加写到一半断电：半个「中」字（UTF-8 三字节只写了两个）、无换行
      final half = utf8.encode('{"type":"message","id":99,"content":"中');
      sessionFile(chatId).writeAsBytesSync(
        half.sublist(0, half.length - 1),
        mode: FileMode.append,
      );

      final chats = await storage.sessionRepository.getAllChats();
      expect(chats.map((c) => c.title), ['中文会话']);

      final id = await addMessage(chatId, '断电后的新消息');
      final messages = await storage.sessionRepository.getMessagesByChatId(
        chatId,
      );
      expect(messages.map((m) => m.content), [
        '第一条',
        '断电后的新消息',
      ], reason: '新消息不能被拼进半截行里一起丢弃');
      expect(messages.last.id, id.id);
    });

    test('没有 meta.json 时新对话与新消息仍使用独立身份', () async {
      final first = await createChat('旧会话');
      await addMessage(first, 'a');
      final lastOld = await addMessage(first, 'b');
      expect(await storage.metaFile.exists(), isFalse);

      final second = await createChat('新会话');
      expect(second, isNot(first));
      expect(
        (await storage.sessionRepository.getChatById(first))!.title,
        '旧会话',
      );

      final newId = await addMessage(first, 'c');
      expect(newId.id, isNot(lastOld.id));
      expect(newId.seq, greaterThan(lastOld.seq));
      final ids = (await storage.sessionRepository.getMessagesByChatId(
        first,
      )).map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: '消息 id 必须唯一');
    });
  });

  group('损坏文件在写入前备份', () {
    test('角色文件损坏后写入，原内容留在备份里', () async {
      const original = 'name: "我的角色"\nprompt: "..."\ntags: [oops\n'; // 截断
      final file = File(p.join(storage.sentinelsDir.path, '7.yaml'));
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(original);

      final store = storage.sentinelRepository;
      await store.getSentinelsCount(); // 只读不备份
      expect(backupsOf(file), isEmpty);

      // 损坏的文件读时按「不存在」处理,不影响其他角色
      expect(await store.getAllSentinels(), isEmpty);
      expect(await store.getSentinelById('7'), isNull);

      // 改写同一个角色前先备份——启动种子看到 0 个角色就会写入默认角色,
      // 「写到一个已存在的损坏文件」正是覆盖的触发点
      await store.createSentinel(const SentinelEntity(id: '7', name: 'Athena'));

      final backups = backupsOf(file);
      expect(backups, hasLength(1));
      expect(backups.single.readAsStringSync(), original);
    });

    test('setting.yaml 语法错误时，保存默认模型前先备份', () async {
      const original = 'model: "sk-unterminated\n';
      storage.settingFile
        ..createSync(recursive: true)
        ..writeAsStringSync(original);

      await storage.userSettings.saveModelId('deepseek-chat');

      final backups = backupsOf(storage.settingFile);
      expect(backups, isNotEmpty);
      expect(backups.first.readAsStringSync(), original);
    });

    test('provider 文件语法错误时，改写前先备份自己', () async {
      const original = 'name: n\napiKey: "sk-unterminated\n';
      final file = File(p.join(storage.providersDir.path, 'broken.yaml'));
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(original);
      // 损坏的 provider 读时跳过，不影响其余 provider
      expect(await storage.providerRepository.getProvidersCount(), 0);
      expect(await storage.providerRepository.getAllProviders(), isEmpty);

      // 改写同一个 provider 前先备份，原内容不会因为整文件覆盖而丢失
      await storage.providerRepository.updateProvider(
        ProviderEntity(
          id: 'broken',
          name: 'n',
          baseUrl: 'https://x',
          apiKey: 'k',
          createdAt: now,
        ),
      );

      final backups = backupsOf(file);
      expect(backups, isNotEmpty);
      expect(backups.first.readAsStringSync(), original);
    });

    test('空的 setting.yaml 是正常的空配置，不产生备份', () async {
      storage.settingFile
        ..createSync(recursive: true)
        ..writeAsStringSync('# 只有注释\n');

      await storage.userSettings.saveModelId('deepseek-chat');

      expect(backupsOf(storage.settingFile), isEmpty);
    });
  });

  group('provider id', () {
    ProviderEntity provider(String name) => ProviderEntity(
      name: name,
      baseUrl: 'https://$name.example',
      apiKey: 'k',
      createdAt: now,
    );

    test('删掉 id 最大的 provider 后新建，不复用它的 id', () async {
      final repo = storage.providerRepository;
      await repo.storeProvider(provider('a'));
      final b = await repo.storeProvider(provider('b'));
      await repo.deleteProvider(b);

      final c = await repo.storeProvider(provider('c'));

      expect(c, isNot(b), reason: '复用会让 b 名下遗留的模型被 c 认领');
      expect(c, matches(r'^[0-9a-f-]{36}$'));
    });

    test('旧配置先迁移身份，新建 provider 不复用旧身份', () async {
      storage.settingFile
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'providers:\n'
          '  - id: 7\n'
          '    name: "legacy"\n'
          '    baseUrl: "https://legacy.example"\n'
          '    apiKey: "k"\n',
        );

      await storage.load();
      final legacy =
          (await storage.providerRepository.getAllProviders()).single;
      final id = await storage.providerRepository.storeProvider(provider('n'));

      expect(id, isNot(legacy.id));
      expect(await storage.providerRepository.getProvidersCount(), 2);
    });
  });

  group('permissions.json', () {
    late File file;
    setUp(() => file = File(p.join(tmp.path, 'permissions.json')));

    PermissionRule deny(String command) =>
        PermissionRule(tool: 'bash', kind: RuleKind.exact, pattern: command);

    test('混合旧规则只加载 deny，保留原文件并不把 allow 转成禁令', () async {
      final content = jsonEncode({
        'rules': [
          {'tool': 'bash', 'kind': 'exact', 'pattern': 'git status'},
          {
            'tool': 'file_write',
            'kind': 'path',
            'pattern': '/workspace',
            'effect': 'allow',
          },
          deny('rm -rf /').toJson(),
        ],
      });
      file.writeAsStringSync(content);
      final store = PermissionStore(file: file, locks: LockRegistry(tmp));
      await store.load();
      expect(store.rules.map((r) => r.pattern), ['rm -rf /']);
      expect(file.readAsStringSync(), content);
      await store.add(deny('git push -f'));
      final reloaded = PermissionStore(file: file, locks: LockRegistry(tmp));
      await reloaded.load();
      expect(reloaded.rules.map((r) => r.pattern), ['rm -rf /', 'git push -f']);
    });

    test('另一实例的写入被看见，也不会被本实例的旧列表覆盖', () async {
      final gui = PermissionStore(file: file, locks: LockRegistry(tmp));
      final tui = PermissionStore(file: file, locks: LockRegistry(tmp));
      await gui.load();
      await tui.load();

      await tui.add(deny('rm -rf /'));
      gui.refreshIfChanged();
      expect(gui.rules.map((r) => r.pattern), ['rm -rf /']);

      // 手工编辑追加一条 deny，随后另一实例添加禁令
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      (json['rules'] as List).add(deny('git push -f').toJson());
      file.writeAsStringSync(jsonEncode(json));
      await gui.add(deny('npm test'));

      final patterns = PermissionStore(file: file, locks: LockRegistry(tmp));
      await patterns.load();
      expect(
        patterns.rules.map((r) => r.pattern),
        containsAll(['rm -rf /', 'git push -f', 'npm test']),
      );
    });

    test('整文件损坏：保留内存中的规则，写入前备份坏文件', () async {
      final store = PermissionStore(file: file, locks: LockRegistry(tmp));
      await store.add(deny('never')); // 未 load：纯内存，不落盘
      expect(file.existsSync(), isFalse);

      await store.load();
      await store.add(deny('rm -rf /'));
      file.writeAsStringSync('{"rules": [ truncated');
      store.refreshIfChanged();
      expect(store.rules.map((r) => r.pattern), [
        'rm -rf /',
      ], reason: '解析失败时不能把 deny 规则清空');

      await store.add(deny('ls'));
      expect(
        backupsOf(file).single.readAsStringSync(),
        '{"rules": [ truncated',
      );
      final reloaded = PermissionStore(file: file, locks: LockRegistry(tmp));
      await reloaded.load();
      expect(reloaded.rules.map((r) => r.pattern), ['rm -rf /', 'ls']);
    });
  });

  group('后台任务登记表', () {
    test('另一个运行中实例的任务不被当成孤儿杀掉，属主已退出的才清理', () async {
      final dir = Directory(p.join(tmp.path, 'bg'))..createSync();
      // 用 exec -a 伪装一个仍在运行的 Athena 实例
      final liveOwner = await Process.start('bash', [
        '-c',
        'exec -a athena-other-instance sleep 60',
      ]);
      final liveTask = await Process.start('bash', ['-c', 'sleep 61']);
      final orphanTask = await Process.start('bash', ['-c', 'sleep 62']);
      addTearDown(() {
        for (final process in [liveOwner, liveTask, orphanTask]) {
          process.kill(ProcessSignal.sigkill);
        }
      });
      final deadOwner = await Process.start('true', []);
      final deadOwnerPid = deadOwner.pid;
      await deadOwner.exitCode;

      final registry = File(p.join(dir.path, 'background_tasks.json'));
      registry.writeAsStringSync(
        jsonEncode([
          {
            'pid': liveTask.pid,
            'owner_pid': liveOwner.pid,
            'command': 'sleep 61',
          },
          {
            'pid': orphanTask.pid,
            'owner_pid': deadOwnerPid,
            'command': 'sleep 62',
          },
        ]),
      );

      final service = BackgroundTaskService(
        stateDirectory: dir,
        locks: LockRegistry(tmp),
      );
      addTearDown(service.dispose);
      final killed = await service.recoverOrphans();

      expect(killed, 1);
      expect(await _isAlive(liveTask.pid), isTrue);
      expect(await _isAlive(orphanTask.pid), isFalse);
      final remaining = jsonDecode(registry.readAsStringSync()) as List;
      expect(remaining.map((e) => e['pid']), [
        liveTask.pid,
      ], reason: '另一实例的记录要原样保留，它崩溃后才清理得到');
    }, skip: Platform.isWindows);
  });
}

Future<bool> _isAlive(int pid) async =>
    (await Process.run('ps', ['-p', '$pid'])).exitCode == 0;
