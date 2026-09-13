import 'dart:convert';

import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('工具名完整展示，描述占满剩余宽度', (tester) async {
    final description =
        '抓取 Artificial Analysis 的 V4.1 Flash 速度与 token 用量对比' * 3;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AthenaColors.dark],
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ToolCard(
                toolName: 'web_fetch',
                arguments: jsonEncode({'call_description': description}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final nameWidth = tester.getSize(find.text('web_fetch')).width;
    final previewWidth = tester.getSize(find.text(description)).width;
    debugPrint('name=$nameWidth preview=$previewWidth');
    // 400 减去 15px 图标与两个 8px 间隙后，名字与描述应占满整行
    expect(nameWidth + previewWidth, closeTo(400 - 15 - 16, 0.5));
  });
}
