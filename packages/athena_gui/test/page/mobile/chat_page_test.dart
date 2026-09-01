import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/mobile/chat/chat.dart';
import 'package:athena_gui/page/mobile/chat/component/sentinel_selector.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../test_utils/fakes.dart';

void main() {
  late ChatViewModel chatViewModel;
  late SentinelViewModel sentinelViewModel;

  setUp(() {
    setupMobileTestDI();
    chatViewModel = GetIt.instance<ChatViewModel>();
    sentinelViewModel = GetIt.instance<SentinelViewModel>();
  });

  /// Helper to pump the chat page with the test app wrapper.
  Future<void> pumpChatPage(
    WidgetTester tester, {
    ChatEntity? chat,
    SentinelEntity? sentinel,
  }) async {
    await tester.pumpWidget(
      wrapWithApp(MobileChatPage(chat: chat, sentinel: sentinel)),
    );
    // Allow async init (initSignals, getSentinels, etc.) to settle
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  group('MobileChatPage rendering', () {
    testWidgets('shows default sentinel name when no chat', (tester) async {
      final sentinel = testSentinel(
        name: 'Athena',
        description: 'A helpful assistant.',
      );
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpChatPage(tester);

      // The sentinel name should be displayed in the placeholder
      expect(find.text('Athena'), findsOneWidget);
      // The page should render the placeholder (not message list)
      expect(find.byType(MobileChatPage), findsOneWidget);
    });

    testWidgets('shows fallback "New Chat" when chat title is empty', (
      tester,
    ) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat(title: '');
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      expect(find.text('New Chat'), findsOneWidget);
    });

    testWidgets('shows chat title when set', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat(title: 'My Conversation');
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      expect(find.text('My Conversation'), findsOneWidget);
    });

    testWidgets('renders user input field', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpChatPage(tester);

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MobileChatPage interaction', () {
    testWidgets('entering and clearing text works', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpChatPage(tester);

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.pumpAndSettle();

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('hint text is visible when input is empty', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpChatPage(tester);

      expect(find.text('Send a message'), findsOneWidget);
    });
  });

  group('MobileChatPage with existing chat', () {
    testWidgets('shows message area when chat exists', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat();
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      // The page should render without errors
      expect(find.byType(MobileChatPage), findsOneWidget);
    });

    testWidgets('shows direct chat instead of hiding a sentinelId 0 chat', (
      tester,
    ) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat(sentinelId: ChatEntity.noSentinelId);
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      expect(find.text(SentinelViewModel.directChatName), findsOneWidget);
      expect(find.text('Athena'), findsNothing);
    });

    testWidgets('no progress bar when agent is idle', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat();
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      // Progress bar should be hidden when iteration <= 0
      expect(find.textContaining('Step'), findsNothing);
    });

    testWidgets('no agent progress info while streaming', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      final chat = testChat();
      sentinelViewModel.sentinels.value = [sentinel];
      chatViewModel.currentChat.value = chat;

      await pumpChatPage(tester, chat: chat);

      // Agent 工作期间也不展示步骤与工具调用等辅助信息。
      chatViewModel.currentIteration.value = 3;
      chatViewModel.currentToolName.value = 'read_file';
      await tester.pumpAndSettle();

      expect(find.textContaining('Step'), findsNothing);
      expect(find.textContaining('read_file'), findsNothing);
    });
  });

  testWidgets('sentinel selector puts direct chat before stored sentinels', (
    tester,
  ) async {
    final sentinel = testSentinel(name: 'Athena');
    sentinelViewModel.sentinels.value = [sentinel];
    SentinelEntity? selected;

    await tester.pumpWidget(
      wrapWithApp(
        MobileSentinelSelectDialog(
          sentinelViewModel: sentinelViewModel,
          onTap: (value) => selected = value,
        ),
      ),
    );
    await tester.pump();

    final direct = find.text(SentinelViewModel.directChatOptionLabel);
    final athena = find.text('Athena');
    expect(direct, findsOneWidget);
    expect(athena, findsOneWidget);
    expect(
      tester.getTopLeft(direct).dy,
      lessThan(tester.getTopLeft(athena).dy),
    );

    await tester.tap(direct);
    expect(selected?.id, ChatEntity.noSentinelId);
  });
}
