import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用 dart:ui 生成真实合法的纯色 PNG，保证测试 codec 能解码。
Future<Uint8List> makePng(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

MessageEntity userMessage(int id, Uint8List bytes) {
  return MessageEntity(
    id: id,
    chatId: 1,
    role: 'user',
    content: 'msg $id',
    imageUrls: base64Encode(bytes),
  );
}

void main() {
  const colors = AthenaColors.dark;

  Future<void> pumpList(
    WidgetTester tester, {
    required List<MessageEntity> messages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(),
          extensions: const [colors],
        ),
        home: Scaffold(
          body: ListView.separated(
            reverse: true,
            itemBuilder: (_, index) => MessageListTile(
              loading: false,
              message: messages.reversed.elementAt(index),
              onResend: () {},
              onSecondaryTapUp: (_) {},
              sentinel: SentinelEntity(id: 1, name: 'athena'),
            ),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 取出用户消息图片当前渲染进 Image.memory 的字节
  Uint8List renderedBytes(WidgetTester tester) {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      if (image.image is MemoryImage) {
        return (image.image as MemoryImage).bytes;
      }
    }
    fail('no MemoryImage rendered');
  }

  testWidgets('列表增长后最新用户消息渲染的是自己的图片', (tester) async {
    final imageA = (await tester.runAsync(() => makePng(const Color(0xFFCCCCCC))))!; // 旧消息的图（占位图标类）
    final imageB = (await tester.runAsync(() => makePng(const Color(0xFF3366FF))))!; // 新消息的图（截图类）

    // 初始：旧消息 + assistant
    await pumpList(tester, messages: [
      userMessage(1, imageA),
      MessageEntity(id: 2, chatId: 1, role: 'assistant', content: 'a'),
    ]);
    expect(renderedBytes(tester), imageA);

    // 新用户消息（图 B）追加到列表末尾（reverse 后为 index 0）
    await pumpList(tester, messages: [
      userMessage(1, imageA),
      MessageEntity(id: 2, chatId: 1, role: 'assistant', content: 'a'),
      userMessage(3, imageB),
    ]);

    // 最新消息（index 0）的图应当是图 B，而不是复用旧图 A
    expect(renderedBytes(tester), imageB);
  });
}
