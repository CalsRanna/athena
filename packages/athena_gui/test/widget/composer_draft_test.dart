import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/home_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// composer 的输入内容（文字与待发图片）按对话分开存：A 里打的字不该跟着进 B，
/// 切回 A 时原来那句还在。
///
/// 为什么必须挂真实的 [DesktopHomePage] 并点真实的侧栏行：页面只有一个
/// `TextEditingController`（草稿态与所有对话共用），而"什么时候换槽"这件事在
/// 页面里；直接调 `ChatViewModel.selectChat` 只覆盖 ViewModel 那一半（换图片槽），
/// 文字串台照样能通过。
void main() {
  late Directory tempRoot;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync(
      'athena_composer_draft_test',
    );
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Finder composerInput() => find.descendant(
    of: find.byType(DesktopMessageInput),
    matching: find.byType(EditableText),
  );

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(composerInput()).controller.text;

  /// 交替「真实异步窗口 + pump」把页面里那条串行 I/O 链推完（原因见 [pumpHome]）。
  Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// 挂起首页并等它初始化完。
  ///
  /// `_initState` 是一串真实文件 I/O，且一个接一个 await：每完成一段，它的
  /// continuation 要等下一帧才排空，下一段又需要新的真实异步窗口。别按固定轮数
  /// 等——多落一条会话就多几段 I/O，写死轮数会在"两条会话"这种用例里悄悄少等
  /// （症状：侧栏还是 "No chats yet"）。等到 ViewModel 真的把 [seededChats] 条
  /// 会话读出来为止，再多走几轮把链尾（角色/工作文件夹 chip）也放干净。
  Future<void> pumpHome(WidgetTester tester, {required int seededChats}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: const DesktopHomePage(),
      ),
    );
    final viewModel = GetIt.instance<ChatViewModel>();
    for (var i = 0; i < 200; i++) {
      if (viewModel.chats.value.length == seededChats) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      viewModel.chats.value.length,
      seededChats,
      reason: '页面初始化没把侧栏里的会话读出来，后面点行都会失败',
    );
    await settle(tester, rounds: 10);
  }

  /// 落一条对话提交给侧栏（页面挂起来之前调用，这样 initSignals 能读到它）。
  Future<ChatEntity> seedChat(WidgetTester tester, String title) async {
    final chatRepo = GetIt.instance<ChatRepository>();
    late ChatEntity chat;
    await tester.runAsync(() async {
      final id = await chatRepo.createChat(
        ChatEntity(
          title: title,
          modelId: 1,
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      chat = (await chatRepo.getChatById(id))!;
    });
    return chat;
  }

  /// 点侧栏里某条对话（等价于用户点它）：走页面注册的 onSelected，因此也会带上
  /// 页面的草稿换槽。
  Future<void> tapChatRow(WidgetTester tester, String title) async {
    var row = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text(title),
    );
    expect(row, findsOneWidget, reason: '侧栏里应有 "$title" 这一行');
    await tester.tap(row);
    await settle(tester);
  }

  /// 点侧栏的 "New chat" 行（顶栏标题在草稿态也是 'New chat'，按侧栏子树定位）。
  Future<void> tapSidebarNewChat(WidgetTester tester) async {
    var newChat = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New chat'),
    );
    expect(newChat, findsOneWidget);
    await tester.tap(newChat);
    await settle(tester);
  }

  Future<void> typeIntoComposer(WidgetTester tester, String text) async {
    await tester.enterText(composerInput(), text);
    await tester.pump();
  }

  testWidgets('切到别的对话：输入框不带上一个对话里打的字', (tester) async {
    await seedChat(tester, 'Chat A');
    await seedChat(tester, 'Chat B');
    await pumpHome(tester, seededChats: 2);

    await tapChatRow(tester, 'Chat A');
    await typeIntoComposer(tester, 'half written in A');
    expect(composerText(tester), 'half written in A');

    await tapChatRow(tester, 'Chat B');
    expect(composerText(tester), '', reason: 'A 里没发出去的字不该跟着进 B 的输入框');
  });

  testWidgets('切回原来的对话：草稿还在', (tester) async {
    await seedChat(tester, 'Chat A');
    await seedChat(tester, 'Chat B');
    await pumpHome(tester, seededChats: 2);

    await tapChatRow(tester, 'Chat A');
    await typeIntoComposer(tester, 'half written in A');
    await tapChatRow(tester, 'Chat B');
    await tapChatRow(tester, 'Chat A');

    expect(
      composerText(tester),
      'half written in A',
      reason: '切回来应恢复这条对话自己的草稿，而不是清空',
    );
  });

  testWidgets('新对话有独立的草稿槽：不继承别的对话，也不会串给别的对话', (tester) async {
    await seedChat(tester, 'Chat A');
    await pumpHome(tester, seededChats: 1);

    // 草稿页（还没落盘的"新对话"）里打半句，切去 A：A 的输入框必须是空的
    await typeIntoComposer(tester, 'draft of new chat');
    await tapChatRow(tester, 'Chat A');
    expect(composerText(tester), '', reason: '草稿页的字不该进 A 的输入框');

    // 回草稿页：那半句还在
    await tapSidebarNewChat(tester);
    expect(
      composerText(tester),
      'draft of new chat',
      reason: '草稿槽只属于"新对话"，切走一趟不该把它弄丢',
    );

    // 再从草稿页切去 A：A 仍然没有草稿（草稿槽没被当成 A 的内容）
    await tapChatRow(tester, 'Chat A');
    expect(composerText(tester), '');
  });

  testWidgets('待发图片按对话分开：切走存回、切回取出', (tester) async {
    final viewModel = GetIt.instance<ChatViewModel>();
    final chatA = await seedChat(tester, 'Chat A');
    final chatB = await seedChat(tester, 'Chat B');

    await tester.runAsync(() => viewModel.selectChat(chatA));
    viewModel.addPendingImage('/tmp/a.png');
    expect(viewModel.pendingImages.value, ['/tmp/a.png']);

    await tester.runAsync(() => viewModel.selectChat(chatB));
    expect(viewModel.pendingImages.value, isEmpty, reason: 'B 不该看见 A 贴的图');

    viewModel.addPendingImage('/tmp/b.png');
    await tester.runAsync(() => viewModel.selectChat(chatA));
    expect(viewModel.pendingImages.value, [
      '/tmp/a.png',
    ], reason: '切回 A 时它自己的图还在');

    await tester.runAsync(() => viewModel.selectChat(chatB));
    expect(viewModel.pendingImages.value, ['/tmp/b.png']);
  });

  testWidgets('草稿槽（还没落盘的新对话）的待发图片同样独立', (tester) async {
    final viewModel = GetIt.instance<ChatViewModel>();
    final chatA = await seedChat(tester, 'Chat A');

    await tester.runAsync(() => viewModel.prepareNewChatDraft());
    viewModel.addPendingImage('/tmp/draft.png');

    await tester.runAsync(() => viewModel.selectChat(chatA));
    expect(viewModel.pendingImages.value, isEmpty, reason: '草稿里贴的图不该出现在 A 上');

    await tester.runAsync(() => viewModel.prepareNewChatDraft());
    expect(viewModel.pendingImages.value, [
      '/tmp/draft.png',
    ], reason: '回到草稿态时草稿里贴的图还在');
  });

  testWidgets('草稿取走即删：表里不留第二份副本', (tester) async {
    final viewModel = GetIt.instance<ChatViewModel>();
    final chatA = await seedChat(tester, 'Chat A');

    viewModel.saveComposerDraft(chatA.id, 'stale');
    expect(viewModel.takeComposerDraft(chatA.id), 'stale');
    expect(
      viewModel.takeComposerDraft(chatA.id),
      '',
      reason: '取回后它的真相在输入框里；表里留着副本会把已经改过的内容顶回去',
    );
  });
}
