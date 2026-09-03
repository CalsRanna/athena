import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/entity/summary_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/page/desktop/home/component/configuration_button.dart';
import 'package:athena_gui/page/mobile/home/component/chat_tile.dart';
import 'package:athena_gui/page/mobile/home/component/new_chat_button.dart';
import 'package:athena_gui/page/mobile/summary/component/summary_list_tile.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

import '../test_utils/fakes.dart';

void main() {
  setUp(setupMobileTestDI);

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pumpThemed(
    WidgetTester tester,
    Widget child, {
    required AthenaColors colors,
    required Brightness brightness,
    bool useGlobalNavigator = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: useGlobalNavigator ? router.navigatorKey : null,
        theme: ThemeData(
          colorScheme: brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light(),
          extensions: [colors],
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('raised home controls always use the raised-surface text color', (
    tester,
  ) async {
    final viewModel = GetIt.instance<ChatViewModel>();
    final chatHistory = ChatHistoryEntity(chat: testChat(title: 'Recent Chat'));

    for (final (colors, brightness) in [
      (AthenaColors.dark, Brightness.dark),
      (AthenaColors.light, Brightness.light),
    ]) {
      await pumpThemed(
        tester,
        Column(
          children: [
            const NewChatButton(),
            ChatTile(chatHistory, viewModel: viewModel),
          ],
        ),
        colors: colors,
        brightness: brightness,
      );

      expect(
        tester.widget<Text>(find.text('New Chat')).style?.color,
        colors.textOnRaised,
      );
      expect(
        tester.widget<Text>(find.text('Recent Chat')).style?.color,
        colors.textOnRaised,
      );
    }
  });

  testWidgets('light technical surfaces use their dedicated icon color', (
    tester,
  ) async {
    final summary = SummaryEntity(
      id: 'summary',
      link: 'https://example.com',
      title: 'Example',
      content: '',
      icon: '',
      createdAt: DateTime(2025),
    );

    for (final (colors, brightness) in [
      (AthenaColors.dark, Brightness.dark),
      (AthenaColors.light, Brightness.light),
    ]) {
      await pumpThemed(
        tester,
        MobileSummaryListTile(summary: summary),
        colors: colors,
        brightness: brightness,
      );

      final icon = tester.widget<Icon>(
        find.byIcon(HugeIcons.strokeRoundedAiBrowser),
      );
      expect(icon.color, colors.iconOnRaised);
    }
  });

  testWidgets('tool avatar background follows the avatar theme token', (
    tester,
  ) async {
    final message = MessageEntity(chatId: 1, role: 'tool', content: 'result');

    for (final (colors, brightness) in [
      (AthenaColors.dark, Brightness.dark),
      (AthenaColors.light, Brightness.light),
    ]) {
      await pumpThemed(
        tester,
        SizedBox(
          width: 600,
          child: MessageListTile(message: message, sentinel: testSentinel()),
        ),
        colors: colors,
        brightness: brightness,
      );

      final avatarContainers = tester.widgetList<Container>(
        find.ancestor(
          of: find.byIcon(HugeIcons.strokeRoundedTools),
          matching: find.byType(Container),
        ),
      );
      final avatar = avatarContainers.firstWhere(
        (container) =>
            container.constraints ==
            const BoxConstraints.tightFor(width: 36, height: 36),
      );
      final decoration = avatar.decoration! as BoxDecoration;
      expect(decoration.color, colors.avatarBackground);
    }
  });

  testWidgets('configuration tooltip foreground matches its themed surface', (
    tester,
  ) async {
    for (final (colors, brightness) in [
      (AthenaColors.dark, Brightness.dark),
      (AthenaColors.light, Brightness.light),
    ]) {
      await pumpThemed(
        tester,
        const Center(
          child: DesktopConfigurationButton(
            currentRetention: -1,
            currentTemperature: 0.7,
          ),
        ),
        colors: colors,
        brightness: brightness,
        useGlobalNavigator: true,
      );

      await tester.tap(find.byType(DesktopConfigurationButton));
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.textStyle?.color, colors.textPrimary);

      Navigator.of(router.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
    }
  });

  test('surface status colors have distinct light and dark variants', () {
    expect(
      AthenaColors.dark.statusWarning,
      isNot(AthenaColors.light.statusWarning),
    );
    expect(
      AthenaColors.dark.statusError,
      isNot(AthenaColors.light.statusError),
    );
    expect(
      AthenaColors.dark.textSecondaryOnRaised,
      isNot(AthenaColors.light.textSecondaryOnRaised),
    );
  });
}
