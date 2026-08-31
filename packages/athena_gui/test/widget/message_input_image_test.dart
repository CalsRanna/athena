import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

import '../test_utils/fakes.dart';

/// 1x1 合法 PNG，供 Image.file / Image.memory 加载。
final Uint8List kPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  const colors = AthenaColors.dark;

  setUp(setupMobileTestDI);
  tearDown(() async {
    await GetIt.instance.reset();
  });

  ThemeData theme() => ThemeData(
        colorScheme: const ColorScheme.dark(),
        extensions: const [colors],
      );

  group('DesktopMessageInput 待发送图片', () {
    late Directory tempDir;
    late List<String> imagePaths;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('athena_input_img');
      imagePaths = [];
      for (var i = 0; i < 2; i++) {
        final path = '${tempDir.path}/img_$i.png';
        await File(path).writeAsBytes(kPngBytes);
        imagePaths.add(path);
      }
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    testWidgets('图片条渲染在输入框边框容器内部', (tester) async {
      final chatViewModel = GetIt.instance<ChatViewModel>();
      chatViewModel.pendingImages.value = imagePaths;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: DesktopMessageInput(controller: TextEditingController()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入框边框容器（TextField 的带 borderStrong 边框的祖先 Container）
      final borderContainer = find.ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration || decoration.border is! Border) {
            return false;
          }
          return (decoration.border as Border).top.color == colors.borderStrong;
        }),
      );
      expect(borderContainer, findsOneWidget,
          reason: '输入框应存在带边框的容器');

      // 图片条应位于边框容器内部（而非独立的顶层列表）
      final stripList = find.descendant(
        of: borderContainer,
        matching: find.byType(ListView),
      );
      expect(stripList, findsOneWidget,
          reason: '待发送图片条应渲染在输入框边框内部');

      // 图片条在输入框内、文字输入框上方
      expect(
        tester.getBottomLeft(stripList).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
      );
    });

    testWidgets('点击移除按钮后待发送图片减少', (tester) async {
      final chatViewModel = GetIt.instance<ChatViewModel>();
      chatViewModel.pendingImages.value = imagePaths;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: DesktopMessageInput(
              controller: TextEditingController(),
              onImageRemoved: chatViewModel.removePendingImage,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(chatViewModel.pendingImages.value.length, 2);
      await tester.tap(
        find.byIcon(HugeIcons.strokeRoundedCancel01).first,
      );
      await tester.pumpAndSettle();

      expect(chatViewModel.pendingImages.value.length, 1);
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.byIcon(HugeIcons.strokeRoundedCancel01),
        findsOneWidget,
      );
    });
  });

  group('用户消息图片顺序', () {
    testWidgets('图片网格渲染在文字之前', (tester) async {
      final message = MessageEntity(
        id: 1,
        chatId: 1,
        role: 'user',
        content: 'hello',
        imageUrls: base64Encode(kPngBytes),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: MessageListTile(
              loading: false,
              message: message,
              sentinel: SentinelEntity(id: 1, name: 'athena'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      expect(
        tester.getTopLeft(grid).dy,
        lessThan(tester.getTopLeft(find.text('hello')).dy),
        reason: '图片应渲染在文字之前（上方）',
      );
    });
  });
}
