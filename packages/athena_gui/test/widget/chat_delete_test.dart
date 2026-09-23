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

/// 删除对话之后的**视图落点**（`ChatViewModel.deleteChat` / `deleteChats`）：
///
/// - 删的不是正在看的那条 → 当前对话与消息原样不动；
/// - 删的正是正在看的那条 → 回草稿态（`currentChat` 为 null），而不是自动
///   落到上一条。
///
/// 这里没有别的可见反馈可断言，用户能看到的只有"视图有没有被换掉"：删完顺手
/// 切到邻居，看起来就像删除顺带做了一次没人要求的跳转。
///
/// 依赖图走 [DI.ensureInitialized]，数据根由 `homeDirOverride` 指到临时目录，
/// 不碰真实的 `~/.athena`（与 `home_page_new_chat_test.dart` 同款脚手架）。
void main() {
  late Directory tempRoot;
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
    tempRoot = Directory.systemTemp.createTempSync('athena_chat_delete_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  /// 落一条带一条 user 消息的对话：有消息才看得出"删别的对话"没有卸载当前视图。
  Future<ChatEntity> seedChat(WidgetTester tester, String title) async {
    late ChatEntity chat;
    await tester.runAsync(() async {
      final chatRepo = GetIt.instance<ChatRepository>();
      final messageRepo = GetIt.instance<MessageRepository>();
      final id = await chatRepo.createChat(
        ChatEntity(
          title: title,
          modelId: 1,
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await messageRepo.storeMessage(
        MessageEntity(chatId: id, role: 'user', content: '$title 的第一句话'),
      );
      chat = (await chatRepo.getChatById(id))!;
    });
    return chat;
  }

  List<int?> chatIds() => viewModel.chats.value.map((c) => c.id).toList();

  List<String> messageContents() =>
      viewModel.messages.value.map((m) => m.content).toList();

  testWidgets('删的不是正在看的那条：当前对话与消息都不动', (tester) async {
    final a = await seedChat(tester, 'Chat A');
    final b = await seedChat(tester, 'Chat B');
    final c = await seedChat(tester, 'Chat C');
    await tester.runAsync(() => viewModel.getChats());
    await tester.runAsync(() => viewModel.selectChat(b));
    expect(messageContents(), ['Chat B 的第一句话'], reason: '前置条件：B 已被选中');

    await tester.runAsync(() => viewModel.deleteChat(c));

    expect(viewModel.currentChat.value?.id, b.id, reason: '删别条不该把视图切走');
    expect(messageContents(), ['Chat B 的第一句话'], reason: '删别条不该卸载当前会话的消息');
    expect(chatIds(), unorderedEquals([a.id, b.id]));
  });

  testWidgets('删的正是正在看的那条：回草稿态，不落到上一条', (tester) async {
    // 用中间那条当当前对话：列表里它前面还有 A，旧实现（落到前一条）会切到 A
    final a = await seedChat(tester, 'Chat A');
    final b = await seedChat(tester, 'Chat B');
    final c = await seedChat(tester, 'Chat C');
    await tester.runAsync(() => viewModel.getChats());
    await tester.runAsync(() => viewModel.selectChat(b));

    await tester.runAsync(() => viewModel.deleteChat(b));

    expect(viewModel.currentChat.value, isNull, reason: '删掉当前对话后应回草稿态');
    expect(messageContents(), isEmpty, reason: '草稿态没有消息');
    expect(chatIds(), unorderedEquals([a.id, c.id]), reason: '被删的那条要出列表');
  });

  testWidgets('删当前对话后：输入框回到"新对话"草稿槽，被删会话的槽清空', (tester) async {
    final b = await seedChat(tester, 'Chat B');
    await seedChat(tester, 'Chat C');
    await tester.runAsync(() => viewModel.getChats());
    viewModel.saveComposerDraft(null, '新对话草稿');
    viewModel.saveComposerDraft(b.id, '写在 B 里的半句话');
    await tester.runAsync(() => viewModel.selectChat(b));

    await tester.runAsync(() => viewModel.deleteChat(b));

    expect(
      viewModel.takeComposerDraft(null),
      '新对话草稿',
      reason: '回草稿态后 composer 该显示"新对话"槽的内容',
    );
    expect(
      viewModel.takeComposerDraft(b.id),
      isEmpty,
      reason: '被删会话的草稿槽没用了（chat id 不复用），不该留在内存里',
    );
  });

  testWidgets('批量删除里包含当前对话：同样回草稿态', (tester) async {
    final a = await seedChat(tester, 'Chat A');
    final b = await seedChat(tester, 'Chat B');
    final c = await seedChat(tester, 'Chat C');
    await tester.runAsync(() => viewModel.getChats());
    await tester.runAsync(() => viewModel.selectChat(b));

    await tester.runAsync(() => viewModel.deleteChats([b, c]));

    expect(viewModel.currentChat.value, isNull, reason: '当前对话在删除集里就该回草稿');
    expect(chatIds(), unorderedEquals([a.id]));
  });

  testWidgets('批量删除里不含当前对话：视图留在原处', (tester) async {
    final a = await seedChat(tester, 'Chat A');
    final b = await seedChat(tester, 'Chat B');
    final c = await seedChat(tester, 'Chat C');
    await tester.runAsync(() => viewModel.getChats());
    await tester.runAsync(() => viewModel.selectChat(b));

    await tester.runAsync(() => viewModel.deleteChats([a, c]));

    expect(viewModel.currentChat.value?.id, b.id, reason: '当前对话不在删除集里，视图不动');
    expect(messageContents(), ['Chat B 的第一句话']);
    expect(chatIds(), unorderedEquals([b.id]));
  });
}
