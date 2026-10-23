import 'dart:async';

import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_gui/component/elicit_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

void main() {
  testWidgets('提问卡默认展开，收起后只留标题行与当前问题', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: ElicitCard(
                request: ElicitRequest(
                  chatId: 'chat-1',
                  questions: const [
                    ElicitQuestion(
                      question: 'Which framework should the widget use?',
                      header: 'stack',
                      options: [
                        ElicitOption(label: 'Flutter', description: ''),
                        ElicitOption(label: 'React', description: ''),
                      ],
                    ),
                  ],
                  completer: Completer<Map<String, String>?>(),
                ),
                maxHeight: 400,
                onSubmit: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final expandedHeight = tester.getSize(find.byType(ElicitCard)).height;
    expect(
      find.ancestor(
        of: find.text('Question'),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(find.text('Question'), findsOneWidget);
    // 收起后问题文本改由标题行承载，卡片只剩这一行
    expect(find.text('Which framework should the widget use?'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);
    expect(find.text('Submit'), findsNothing);
    expect(
      tester.getSize(find.byType(ElicitCard)).height,
      lessThan(expandedHeight),
    );

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });
}
