import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/page/desktop/home/component/configuration_button.dart';
import 'package:athena_gui/page/mobile/home/component/chat_tile.dart';
import 'package:athena_gui/page/mobile/home/component/new_chat_button.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

import '../test_utils/fakes.dart';

/// WCAG 相对对比度，用于守住「代码文字在代码底上始终可读」。
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

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

  test('header shimmer follows the theme instead of hardcoded white', () {
    final dark = ToolHeaderShimmer.colorsFor(AthenaColors.dark);
    // 深色主题保持历史观感：白色只调透明度
    expect(dark.base, Colors.white.withValues(alpha: 0.45));
    expect(dark.highlight, Colors.white.withValues(alpha: 0.95));

    // srcIn 会把 header 整块涂成 shimmer 颜色，浅色主题必须与浅色页面成对比，
    // 否则折叠头就是白底白字（此前写死 Colors.white 的 bug）
    final light = ToolHeaderShimmer.colorsFor(AthenaColors.light);
    expect(
      _contrastRatio(light.base, AthenaColors.light.surface),
      greaterThan(3),
    );
    expect(
      _contrastRatio(light.highlight, AthenaColors.light.surface),
      greaterThan(3),
    );
  });

  test('code surfaces stay recessed and readable in both themes', () {
    for (final colors in [AthenaColors.dark, AthenaColors.light]) {
      // 层级：cardHeader 比 codeBackground 深一档，两者都比页面底色深。
      // 深色主题曾经的近白代码块在深色页面上会抢走全部注意力。
      expect(
        colors.codeBackground.computeLuminance(),
        lessThan(colors.surface.computeLuminance()),
      );
      expect(
        colors.cardHeader.computeLuminance(),
        lessThan(colors.codeBackground.computeLuminance()),
      );
      expect(
        _contrastRatio(colors.textOnCode, colors.codeBackground),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(colors.textSecondaryOnCode, colors.cardHeader),
        greaterThan(4.5),
      );
    }
  });

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

  testWidgets('assistant messages paint no card background in either theme', (
    tester,
  ) async {
    final message = MessageEntity(
      id: 1,
      chatId: 1,
      role: 'assistant',
      content: 'reply',
    );

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

      // 助手消息不给底板：既没有画背景的卡面容器，段自身也不是 Container。
      // 相邻同色底板在非整数像素边界上会留下 1 像素接缝；不画底板既没有接缝，
      // 也就不用把整卡塞进一个列表项（成因见 card_seam_mechanism_test.dart）。
      expect(
        find.byKey(const ValueKey('assistant-card-surface-1')),
        findsNothing,
      );
      expect(
        tester.widget(find.byKey(const ValueKey('assistant-card-segment-1'))),
        isNot(isA<Container>()),
      );
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
