import 'dart:async';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/component/sentinel_placeholder.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/main.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/mobile/chat/component/user_input.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:athena_gui/widget/workspace_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;

  setUp(() {
    SharedPreferences.setMockInitialValues({'text_size': 'large'});
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          (_) async => null,
        );
    tempRoot = Directory.systemTemp.createTempSync('athena_text_size_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    DesktopContextMenuManager.instance.dismiss();
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  Future<void> settle(WidgetTester tester) async {
    // 页面初始化包含串行文件 I/O，需要交替推进真实异步与界面帧。
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester, Finder parent) {
    return tester.renderObject<RenderParagraph>(
      find.descendant(of: parent, matching: find.byType(RichText)).first,
    );
  }

  void expectTextScale(WidgetTester tester, Finder parent, double scale) {
    expect(
      paragraph(tester, parent).textScaler.scale(20),
      closeTo(20 * scale, 0.001),
    );
  }

  void expectInputScale(WidgetTester tester, Type input, double scale) {
    final editable = tester.state<EditableTextState>(
      find.descendant(
        of: find.byType(input),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      editable.renderEditable.textScaler.scale(20),
      closeTo(20 * scale, 0.001),
    );
  }

  void expectTypography(
    WidgetTester tester,
    String text,
    double fontSize,
    double lineHeight,
    TextScaler systemScaler, {
    bool mono = false,
  }) {
    final rendered = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().trim() == text,
    );
    expect(rendered, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(rendered);
    final styles = <TextStyle>[];
    void collectStyles(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      if (span.text?.trim().isNotEmpty ?? false) styles.add(style);
      for (final child in span.children ?? <InlineSpan>[]) {
        collectStyles(child, style);
      }
    }
    collectStyles(paragraph.text, const TextStyle());
    expect(styles, isNotEmpty);
    for (final style in styles) {
      expect(style.fontSize, fontSize, reason: text);
      expect(style.height! * style.fontSize!, closeTo(lineHeight, 0.001));
      if (mono) expect(style.fontFamily, AthenaFont.mono);
      expect(
        paragraph.textScaler.scale(style.fontSize!),
        closeTo(systemScaler.scale(fontSize), 0.001),
        reason: '固定字号只叠加系统缩放：$text',
      );
    }
  }

  (double, double) proseMetrics(AthenaTextSize size) => switch (size) {
    AthenaTextSize.small => (13, 20),
    AthenaTextSize.medium => (14, 22),
    AthenaTextSize.large => (15, 24),
  };

  void expectMessageTypography(WidgetTester tester, AthenaTextSize size) {
    final (fontSize, lineHeight) = proseMetrics(size);
    const systemScaler = TextScaler.linear(1.2);
    for (final text in ['User message probe', 'Assistant message probe']) {
      expectTypography(tester, text, fontSize, lineHeight, systemScaler);
    }
    expectTypography(
      tester, 'print(42);', fontSize, lineHeight, systemScaler, mono: true,
    );
  }

  testWidgets(
    'Text size gives messages and code the same fixed styles, excluding other UI',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final settings = GetIt.instance<SettingViewModel>();
      await tester.runAsync(settings.initTextSize);
      // 挂真实应用根节点，防止字号设置再次被挪回 MaterialApp 全局。
      await tester.pumpWidget(const AthenaApp());
      await settle(tester);
      // 尺寸比较必须等草稿角色初始化完成，不能拿加载占位与最终角色比较。
      for (var i = 0; i < 100 &&
          GetIt.instance<ChatViewModel>().currentSentinel.value == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(GetIt.instance<ChatViewModel>().currentSentinel.value, isNotNull);
      await tester.pumpAndSettle();

      final sidebar = find.descendant(
        of: find.byType(DesktopChatListView),
        matching: find.text('New chat'),
      );
      final title = find.descendant(
        of: find.byType(AthenaAppBar),
        matching: find.text('New chat'),
      );
      final sidebarSize = paragraph(tester, sidebar).size;
      final titleSize = paragraph(tester, title).size;
      expectTextScale(tester, sidebar, 1.2);
      expectTextScale(tester, title, 1.2);
      final placeholderSize = paragraph(
        tester,
        find.byType(SentinelPlaceholder),
      ).size;
      final composerSize = tester.getSize(find.byType(DesktopMessageInput));
      expectTextScale(tester, find.byType(SentinelPlaceholder), 1.2);
      expectInputScale(tester, DesktopMessageInput, 1.2);

      unawaited(
        router.push(
          DesktopSettingRoute(children: [const DesktopSettingGeneralRoute()]),
        ),
      );
      await settle(tester);
      final settingsLabelSize = paragraph(tester, find.text('Text size')).size;
      for (final size in AthenaTextSize.values) {
        await tester.tap(find.text(size.label));
        await settle(tester);
        expectTextScale(tester, find.byType(SentinelPlaceholder), 1.2);
        expectInputScale(tester, DesktopMessageInput, 1.2);
        expect(
          paragraph(tester, find.byType(SentinelPlaceholder)).size,
          placeholderSize,
        );
        expect(tester.getSize(find.byType(DesktopMessageInput)), composerSize);
        expectTextScale(tester, sidebar, 1.2);
        expectTextScale(tester, title, 1.2);
        expectTextScale(tester, find.text('Text size'), 1.2);
        expect(paragraph(tester, sidebar).size, sidebarSize);
        expect(paragraph(tester, title).size, titleSize);
        expect(
          paragraph(tester, find.text('Text size')).size,
          settingsLabelSize,
        );
      }

      await router.maybePop();
      await settle(tester);
      DesktopContextMenuManager.instance.show(
        tester.element(find.byType(DesktopMessageInput)),
        const DesktopContextMenu(
          offset: Offset(400, 100),
          children: [DesktopContextMenuTile(text: 'Workspace menu')],
        ),
      );
      await tester.pumpAndSettle();
      expectTextScale(tester, find.text('Workspace menu'), 1.2);
      DesktopContextMenuManager.instance.dismiss();

      final chatViewModel = GetIt.instance<ChatViewModel>();
      late ChatEntity conversation;
      await tester.runAsync(() async {
        final chats = GetIt.instance<ChatRepository>();
        final messages = GetIt.instance<MessageRepository>();
        final chatId = await chats.createChat(
          ChatEntity(
            title: 'Text size conversation',
            modelId: '0',
            sentinelId: ChatEntity.noSentinelId,
            createdAt: DateTime(2026, 9, 24),
            updatedAt: DateTime(2026, 9, 24),
          ),
        );
        conversation = (await chats.getChatById(chatId))!;
        await messages.storeMessage(
          MessageEntity(
            chatId: chatId,
            role: 'user',
            content: 'User message probe',
          ),
        );
        await messages.storeMessage(
          MessageEntity(
            chatId: chatId,
            role: 'assistant',
            content: 'Assistant message probe\n\n```dart\nprint(42);\n```',
          ),
        );
        await chatViewModel.getChats();
        await chatViewModel.selectChat(conversation);
      });
      await settle(tester);
      for (final size in AthenaTextSize.values) {
        await tester.runAsync(() => settings.setTextSize(size));
        await settle(tester);
        expectMessageTypography(tester, size);
        expectInputScale(tester, DesktopMessageInput, 1.2);
        expect(tester.getSize(find.byType(DesktopMessageInput)), composerSize);
      }

      unawaited(router.push(MobileChatRoute()));
      await settle(tester);
      for (final size in AthenaTextSize.values) {
        await tester.runAsync(() => settings.setTextSize(size));
        await settle(tester);
        expectTextScale(tester, find.byType(SentinelPlaceholder), 1.2);
        expectInputScale(tester, UserInput, 1.2);
        expectTextScale(tester, find.text('New Chat'), 1.2);
      }
      await tester.runAsync(() => chatViewModel.selectChat(conversation));
      await settle(tester);
      final mobileComposerSize = tester.getSize(find.byType(UserInput));
      for (final size in AthenaTextSize.values) {
        await tester.runAsync(() => settings.setTextSize(size));
        await settle(tester);
        expectMessageTypography(tester, size);
        expectInputScale(tester, UserInput, 1.2);
        expect(tester.getSize(find.byType(UserInput)), mobileComposerSize);
        expectTextScale(tester, find.text('Text size conversation'), 1.2);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets('Fixed Markdown presets preserve nonlinear system scaling',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const systemScaler = _NonlinearTextScaler();
    final message = MessageEntity(
      chatId: 'typography-probe',
      role: 'assistant',
      content: '# Heading probe\n\n'
          'Paragraph probe\n\n'
          '> Quote probe\n\n'
          '- List probe\n\n'
          '| Table header |\n| --- |\n| Table cell |\n\n'
          '[Link probe](https://example.com)\n\n'
          '`inline_code`\n\n'
          '```dart\nprint(42);\n```',
    );
    for (final size in AthenaTextSize.values) {
      await tester.pumpWidget(MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: systemScaler),
          child: Scaffold(
            body: AthenaWorkspaceTextSize(
              size: size,
              child: Column(
                children: [
                  AthenaMarkdown(message: message),
                  const StepResultBody(text: 'Tool output probe'),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final (fontSize, lineHeight) = proseMetrics(size);
      for (final text in [
        'Heading probe',
        'Paragraph probe',
        'Quote probe',
        'List probe',
        'Table header',
        'Table cell',
        'Link probe',
      ]) {
        expectTypography(tester, text, fontSize, lineHeight, systemScaler);
      }
      for (final text in ['inline_code', 'print(42);', 'Tool output probe']) {
        expectTypography(
          tester, text, fontSize, lineHeight, systemScaler, mono: true,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize + (fontSize < 14 ? 3 : 4);

  @override
  double get textScaleFactor => 1.2;
}
