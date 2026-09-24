import 'dart:async';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/util/clipboard_image_service.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pasteboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final defaultTempDir = ClipboardImageService.tempDirProvider;
  late Directory tempRoot;
  late ChatViewModel viewModel;
  late Uint8List png;

  setUp(() {
    var clipboardText = '';
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String;
          return null;
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.hasStrings':
          return {'value': clipboardText.isNotEmpty};
        default:
          return null;
      }
    });
    SharedPreferences.setMockInitialValues({});
    tempRoot = Directory.systemTemp.createTempSync('athena_clipboard_test');
    ClipboardImageService.tempDirProvider = () async => tempRoot;
    png = File('asset/image/launcher_icon_macos_512x512.png').readAsBytesSync();
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    ClipboardImageService.tempDirProvider = defaultTempDir;
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<TextEditingController> pumpInput(
    WidgetTester tester, {
    VoidCallback? onSubmitted,
  }) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: DesktopMessageInput(
            controller: controller,
            focusNode: focus,
            onPasteImages: viewModel.pasteClipboardImages,
            onImageRemoved: viewModel.removePendingImage,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    return controller;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  void pasteIntent(WidgetTester tester) {
    Actions.invoke(
      tester.element(find.byType(EditableText)),
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
  }

  testWidgets(
    'standard paste shows progress before bytes arrive and then renders image',
    (tester) async {
      final reading = Completer<Uint8List?>();
      final preparing = Completer<Directory>();
      ClipboardImageService.tempDirProvider = () => preparing.future;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'files' ? <String>[] : await reading.future,
      );
      var sent = 0;
      final controller = await pumpInput(tester, onSubmitted: () => sent++);
      await tester.enterText(find.byType(TextField), 'Look at this');
      pasteIntent(tester);
      await tester.pump();

      expect(
        viewModel.pendingImages.value.single.stage,
        PendingImageStage.reading,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final label in ['Reading', 'Preparing', 'Decoding']) {
        expect(find.text(label), findsNothing, reason: '占位不展示阶段名称');
      }
      final placeholderSize = tester.getSize(
        find.byType(CircularProgressIndicator),
      );
      expect(placeholderSize.width, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byIcon(LucideIcons.arrowUp));
      expect(sent, 0, reason: '解析期间按钮与回车都不能漏发附件');

      reading.complete(png);
      await tester.pump();
      expect(
        viewModel.pendingImages.value.single.stage,
        PendingImageStage.preparing,
      );
      preparing.complete(tempRoot);
      await settle(tester);

      expect(viewModel.pendingImages.value.single.isReady, isTrue);
      expect(viewModel.pendingImages.value.single.bytes, png);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is RawImage && w.image != null),
        findsOneWidget,
      );
      expect(controller.text, 'Look at this');
      await tester.tap(find.byIcon(LucideIcons.arrowUp));
      expect(sent, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final modifier in [
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.controlLeft,
  ]) {
    testWidgets('paste shortcut $modifier renders every copied file in order', (
      tester,
    ) async {
      final first = File('${tempRoot.path}/first.PNG')..writeAsBytesSync(png);
      final second = File('${tempRoot.path}/second.png')..writeAsBytesSync(png);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'files', reason: '复制文件不能再读文件图标预览');
        return [first.path, second.path];
      });
      await pumpInput(tester);
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(modifier);
      await settle(tester);
      expect(viewModel.pendingImages.value.map((image) => image.path), [
        first.path,
        second.path,
      ]);
      expect(
        viewModel.pendingImages.value.every((image) => image.isReady),
        isTrue,
      );
      expect(
        find.byWidgetPredicate((w) => w is RawImage && w.image != null),
        findsNWidgets(2),
      );
    });
  }

  testWidgets('context menu paste accepts an image-only clipboard', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'files' ? <String>[] : png,
    );
    await pumpInput(tester);
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.showToolbar();
    await tester.pump();
    expect(find.text('Paste'), findsOneWidget);
    await tester.tap(find.text('Paste'));
    await settle(tester);
    expect(viewModel.pendingImages.value.single.isReady, isTrue);
    expect(
      find.byWidgetPredicate((w) => w is RawImage && w.image != null),
      findsOneWidget,
    );
  });

  testWidgets('text paste replaces selection and leaves no image placeholder', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'files' ? <String>[] : null,
    );
    final controller = await pumpInput(tester);
    await Clipboard.setData(const ClipboardData(text: 'world'));
    controller.value = const TextEditingValue(
      text: 'hello there',
      selection: TextSelection(baseOffset: 6, extentOffset: 11),
    );
    pasteIntent(tester);
    await settle(tester);
    expect(controller.text, 'hello world');
    expect(viewModel.pendingImages.value, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('removing placeholder prevents late image from reappearing', (
    tester,
  ) async {
    final reading = Completer<Uint8List?>();
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'files' ? <String>[] : await reading.future,
    );
    await pumpInput(tester);
    pasteIntent(tester);
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.x));
    reading.complete(png);
    await settle(tester);
    expect(viewModel.pendingImages.value, isEmpty);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bad image displays failure and can be removed', (tester) async {
    final badFile = File('${tempRoot.path}/broken.png')
      ..writeAsStringSync('not an image');
    messenger.setMockMethodCallHandler(channel, (call) async => [badFile.path]);
    await pumpInput(tester);
    pasteIntent(tester);
    await settle(tester);
    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
    expect(
      viewModel.pendingImages.value.single.stage,
      PendingImageStage.failed,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    expect(viewModel.pendingImages.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight paste stays in its original chat', (tester) async {
    final reading = Completer<Uint8List?>();
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'files' ? <String>[] : await reading.future,
    );
    late ChatEntity chat;
    await tester.runAsync(() async {
      final repo = GetIt.instance<ChatRepository>();
      final id = await repo.createChat(
        ChatEntity(
          title: 'Other chat',
          modelId: 1,
          sentinelId: ChatEntity.noSentinelId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      chat = (await repo.getChatById(id))!;
    });
    await pumpInput(tester);
    pasteIntent(tester);
    await tester.pump();
    await tester.runAsync(() => viewModel.selectChat(chat));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    reading.complete(png);
    await settle(tester);
    expect(viewModel.pendingImages.value, isEmpty);
    await tester.runAsync(() => viewModel.prepareNewChatDraft());
    await settle(tester);
    expect(viewModel.pendingImages.value.single.isReady, isTrue);
    expect(
      find.byWidgetPredicate((w) => w is RawImage && w.image != null),
      findsOneWidget,
    );
  });

  testWidgets('unsupported copied files never paste their icon preview', (
    tester,
  ) async {
    final file = File('${tempRoot.path}/notes.txt')..writeAsStringSync('hello');
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'files');
      return [file.path];
    });
    final controller = await pumpInput(tester);
    await Clipboard.setData(const ClipboardData(text: 'notes.txt'));
    pasteIntent(tester);
    await settle(tester);
    expect(controller.text, 'notes.txt');
    expect(viewModel.pendingImages.value, isEmpty);
  });
}
