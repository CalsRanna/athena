import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
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

  Future<int> createChat(String title) => storage.sessionRepository.createChat(
    ChatEntity(
      title: title,
      modelId: 1,
      sentinelId: 1,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<int> addMessage(int chatId, String content) =>
      storage.sessionRepository.storeMessage(
        MessageEntity(chatId: chatId, role: 'user', content: content),
      );

  File sessionFile(int chatId) =>
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
      expect(messages.last.id, id);
    });

    test('meta.json 丢失后新对话不覆盖已有会话，新消息 id 不与旧消息重复', () async {
      final first = await createChat('旧会话');
      await addMessage(first, 'a');
      final lastOld = await addMessage(first, 'b');
      storage.metaFile.deleteSync();

      final second = await createChat('新会话');
      expect(second, isNot(first));
      expect(
        (await storage.sessionRepository.getChatById(first))!.title,
        '旧会话',
      );

      final newId = await addMessage(first, 'c');
      expect(newId, greaterThan(lastOld));
      final ids = (await storage.sessionRepository.getMessagesByChatId(
        first,
      )).map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: '消息 id 必须唯一');
    });
  });

  group('损坏文件在写入前备份', () {
    test('sentinels.json 损坏后写入，原内容留在备份里', () async {
      const original = '[{"id": 1, "name": "我的角色", "prompt": "..."'; // 截断
      storage.sentinelsFile
        ..createSync(recursive: true)
        ..writeAsStringSync(original);

      await storage.sentinelRepository.getSentinelsCount(); // 只读不备份
      expect(backupsOf(storage.sentinelsFile), isEmpty);

      final store = storage.sentinelRepository;
      expect(await store.getAllSentinels(), isEmpty);
      // 启动种子看到 0 个角色就会写入默认角色——正是覆盖的触发点
      await store.createSentinel(SentinelEntity(name: 'Athena'));

      final backups = backupsOf(storage.sentinelsFile);
      expect(backups, hasLength(1));
      expect(backups.single.readAsStringSync(), original);
    });

    test('setting.yaml 语法错误时，保存 provider / 默认模型前先备份', () async {
      const original = 'providers:\n  - id: 1\n    apiKey: "sk-unterminated\n';
      storage.settingFile
        ..createSync(recursive: true)
        ..writeAsStringSync(original);

      await storage.userSettings.saveModelId('deepseek-chat');
      await storage.providerRepository.storeProvider(
        ProviderEntity(
          name: 'n',
          baseUrl: 'https://x',
          apiKey: 'k',
          createdAt: now,
        ),
      );

      final backups = backupsOf(storage.settingFile);
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

  group('permissions.json', () {
    late File file;
    setUp(() => file = File(p.join(tmp.path, 'permissions.json')));

    PermissionRule deny(String command) => PermissionRule(
      tool: 'bash',
      kind: RuleKind.exact,
      pattern: command,
      effect: RuleEffect.deny,
    );

    test('另一实例的写入被看见，也不会被本实例的旧列表覆盖', () async {
      final gui = PermissionStore(file: file);
      final tui = PermissionStore(file: file);
      await gui.load();
      await tui.load();

      await tui.add(deny('rm -rf /'));
      gui.refreshIfChanged();
      expect(gui.rules.map((r) => r.pattern), ['rm -rf /']);

      // 手工编辑追加一条 deny，随后 GUI 点「始终允许」
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      (json['rules'] as List).add(deny('git push -f').toJson());
      file.writeAsStringSync(jsonEncode(json));
      await gui.add(PermissionRule.forToolCall('bash', 'npm test').single);

      final patterns = PermissionStore(file: file);
      await patterns.load();
      expect(
        patterns.rules.map((r) => r.pattern),
        containsAll(['rm -rf /', 'git push -f', 'npm test']),
      );
    });

    test('整文件损坏：保留内存中的规则，写入前备份坏文件', () async {
      final store = PermissionStore(file: file);
      await store.add(deny('never')); // 未 load：纯内存，不落盘
      expect(file.existsSync(), isFalse);

      await store.load();
      await store.add(deny('rm -rf /'));
      file.writeAsStringSync('{"rules": [ truncated');
      store.refreshIfChanged();
      expect(store.rules.map((r) => r.pattern), [
        'rm -rf /',
      ], reason: '解析失败时不能把 deny 规则清空');

      await store.add(PermissionRule.forToolCall('bash', 'ls').single);
      expect(
        backupsOf(file).single.readAsStringSync(),
        '{"rules": [ truncated',
      );
      final reloaded = PermissionStore(file: file);
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

      final service = BackgroundTaskService(stateDirectory: dir);
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
