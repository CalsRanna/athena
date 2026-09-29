import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 窗口分页的表征测试。
///
/// `loadOlderMessages` / `_loadMessagePage` 此前零覆盖，而它是 ViewModel 里守卫
/// 最多的一条路径：`_loadingOlderMessages` 防重入、`_messageLoadGeneration` 防
/// 「切了对话还在往新列表里塞」、`_olderLoadGeneration` 防并发两次加载互相覆盖，
/// 外加 `_oldestLoadedMessageSeq` 的维护。这里把可观测行为钉住。
///
/// 仓储换成 [_FakeMessageRepo]：窗口大小与「加载什么时候返回」都能精确控制。
/// 必须在解析 `ChatViewModel` **之前**替换，因为它在构造时就取走了仓储。
void main() {
  late Directory tempRoot;
  late _FakeMessageRepo messages;
  late ChatViewModel viewModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_pagination_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    messages = _FakeMessageRepo();
    GetIt.instance.unregister<MessageRepository>();
    GetIt.instance.registerSingleton<MessageRepository>(messages);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<ChatEntity> seedChat(WidgetTester tester, String title) async {
    late ChatEntity chat;
    await tester.runAsync(() async {
      final repo = GetIt.instance<ChatRepository>();
      final id = await repo.createChat(
        ChatEntity(
          title: title,
          modelId: '1',
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      chat = (await repo.getChatById(id))!;
    });
    return chat;
  }

  Future<ChatEntity> select(WidgetTester tester, String title) async {
    final chat = await seedChat(tester, title);
    await tester.runAsync(() => viewModel.selectChat(chat));
    return chat;
  }

  List<int> seqs() => [for (final m in viewModel.messages.value) m.seq];

  const pageSize = ChatViewModel.messagePageSize;

  testWidgets('会话不超过一页：整段给，且不再翻页', (tester) async {
    messages.total = pageSize;
    await select(tester, '小会话');

    expect(seqs(), List.generate(pageSize, (i) => i));
    expect(viewModel.hasOlderMessages, isFalse);

    final added = await tester.runAsync(() => viewModel.loadOlderMessages());
    expect(added, 0);
  });

  testWidgets('大会话首屏只给最后一页，hasOlder 为真', (tester) async {
    messages.total = pageSize * 2 + 7;
    await select(tester, '大会话');

    expect(
      seqs(),
      List.generate(pageSize, (i) => messages.total - pageSize + i),
    );
    expect(viewModel.hasOlderMessages, isTrue);
  });

  testWidgets('向前翻页：prepend 一页，返回新增条数', (tester) async {
    messages.total = pageSize * 2 + 7;
    await select(tester, '大会话');
    final firstWindow = seqs();

    final added = await tester.runAsync(() => viewModel.loadOlderMessages());

    expect(added, pageSize);
    // 不断言具体下标：取页时多读一条做预读（`pageSize + 1`），页边界因此会滑动。
    // 真正要守的是结构性质——接在前面、连续、不重复、原窗口仍是新窗口的后缀。
    final window = seqs();
    expect(window.first, lessThan(firstWindow.first), reason: '更早的一条接在前面');
    expect(window.last, messages.total - 1, reason: '尾部不动');
    expect(window.toSet(), hasLength(window.length), reason: '不重复');
    expect(
      window.sublist(window.length - firstWindow.length),
      firstWindow,
      reason: '原窗口原样留作后缀',
    );
    expect(viewModel.hasOlderMessages, isTrue, reason: '文件头那几条还在');
  });

  testWidgets('翻到文件头：hasOlder 转假，再翻返回 0', (tester) async {
    messages.total = pageSize + 7;
    await select(tester, '大会话');

    final added = await tester.runAsync(() => viewModel.loadOlderMessages());

    expect(added, 7);
    expect(seqs(), List.generate(messages.total, (i) => i));
    expect(viewModel.hasOlderMessages, isFalse);

    final again = await tester.runAsync(() => viewModel.loadOlderMessages());
    expect(again, 0);
  });

  testWidgets('前一次加载还没回来时再翻是 no-op（不排队、不重复加页）', (tester) async {
    messages.total = pageSize * 3;
    await select(tester, '大会话');
    final before = seqs();

    messages.olderDelay = const Duration(milliseconds: 50);
    await tester.runAsync(() async {
      final first = viewModel.loadOlderMessages(); // 还在 IO 上
      final second = await viewModel.loadOlderMessages();
      expect(second, 0, reason: '重入守卫：第二次直接返回');
      await first;
    });

    expect(seqs(), hasLength(before.length + pageSize), reason: '只加了一页');
  });

  testWidgets('加载期间切了对话：结果丢弃，不写进新列表', (tester) async {
    messages.total = pageSize * 3;
    await select(tester, 'A');
    final other = await seedChat(tester, 'B');

    messages.olderDelay = const Duration(milliseconds: 50);
    await tester.runAsync(() async {
      final loading = viewModel.loadOlderMessages();
      // 期间切到 B：切走会重新加载窗口并重置分页代次
      await viewModel.selectChat(other);
      final bWindow = seqs();

      expect(await loading, 0, reason: '过期结果不返回条数');
      expect(seqs(), bWindow, reason: 'A 的那一页不能混进 B');
    });
  });

  testWidgets('重新选会话重置分页状态', (tester) async {
    messages.total = pageSize * 3;
    await select(tester, 'A');
    await tester.runAsync(() => viewModel.loadOlderMessages());
    expect(viewModel.hasOlderMessages, isTrue);

    // 换一条小会话：hasOlder 必须按新会话重新算，而不是留着上一条的
    messages.total = 3;
    final other = await seedChat(tester, 'C');
    await tester.runAsync(() => viewModel.selectChat(other));

    expect(seqs(), [0, 1, 2]);
    expect(viewModel.hasOlderMessages, isFalse);
  });
}

/// 可控的消息仓储：消息是 seq 0..total-1 的 user 消息（顺带当轮次起点）。
///
/// [olderDelay] 让**只有向前翻页**慢下来，用例借此制造「翻页还没回来」的窗口，
/// 用来验证重入守卫与「切了对话」的守卫。
///
/// 刻意只延迟向前翻页：切对话那类用例要在翻页未返回时照常完成新会话的首屏。
/// 用的是真实延迟而不是手动完成的 Completer——后者要跨 `runAsync` 的 zone 推进，
/// 容易写出自己等自己的死锁。
class _FakeMessageRepo implements MessageRepository, RecentMessageRepository {
  int total = 0;

  Duration olderDelay = Duration.zero;

  List<MessageEntity> _all(String chatId) => [
    for (var i = 0; i < total; i++)
      MessageEntity(
        id: 'm$i',
        chatId: chatId,
        role: 'user',
        content: 'c$i',
        seq: i,
      ),
  ];

  @override
  Future<MessageWindow> loadInitialMessages(
    String chatId, {
    required int pageSize,
  }) async {
    final all = _all(chatId);
    if (all.length <= pageSize) return (messages: all, hasOlder: false);
    return (messages: all.sublist(all.length - pageSize), hasOlder: true);
  }

  @override
  Future<List<MessageEntity>> loadRecentMessages(
    String chatId, {
    required int count,
    int? beforeSeq,
  }) async {
    await Future<void>.delayed(olderDelay);
    final all = _all(chatId);
    final eligible = beforeSeq == null
        ? all
        : all.where((message) => message.seq < beforeSeq).toList();
    if (eligible.length <= count) return eligible;
    return eligible.sublist(eligible.length - count);
  }

  @override
  Future<List<String>> getTurnStartIds(String chatId) async => [
    for (final message in _all(chatId)) message.id!,
  ];

  // 下面这些不在分页路径上。显式抛错而不是返回假数据：将来若有人把它们接进
  // 分页路径，测试会立刻炸，而不是悄悄拿到空结果。
  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    String chatId, {
    bool includeCompacted = true,
  }) async => _all(chatId);

  @override
  Future<MessageEntity?> getMessageById(String chatId, String id) =>
      throw UnimplementedError();

  @override
  Future<MessageEntity> storeMessage(MessageEntity message) =>
      throw UnimplementedError();

  @override
  Future<void> updateMessage(MessageEntity message) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessages(String chatId, Set<String> ids) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessagesByChatId(String chatId) =>
      throw UnimplementedError();

  @override
  Future<int> getMessagesCount(String chatId) async => total;

  @override
  Future<void> markAsCompacted(String chatId, Set<String> ids) =>
      throw UnimplementedError();

  @override
  Future<MessageEntity?> getLatestMessageByChatId(String chatId) =>
      throw UnimplementedError();
}
