import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/queued_messages.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpQueue(
    WidgetTester tester,
    List<MessageEntity> messages, {
    AthenaColors colors = AthenaColors.dark,
    double width = 720,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [colors]),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: QueuedMessages(messages: messages),
          ),
        ),
      ),
    ),
  );

  testWidgets('empty queues take no space', (tester) async {
    await pumpQueue(tester, []);
    expect(find.textContaining('Queued'), findsNothing);
    expect(tester.getSize(find.byType(QueuedMessages)).height, 0);
  });

  for (final colors in [AthenaColors.dark, AthenaColors.light]) {
    testWidgets(
      'queue shows text and images at narrow width (${colors == AthenaColors.dark ? 'dark' : 'light'})',
      (tester) async {
        final messages = [
          MessageEntity(
            chatId: 1,
            role: 'user',
            content: 'Check the latest changes',
          ),
          MessageEntity(
            chatId: 1,
            role: 'user',
            imageUrls: 'image-one,image-two',
          ),
        ];
        await pumpQueue(tester, messages, colors: colors, width: 300);
        expect(find.text('Queued (2)'), findsOneWidget);
        expect(find.text('Check the latest changes'), findsOneWidget);
        expect(find.text('2 images'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await pumpQueue(
          tester,
          messages.skip(1).toList(),
          colors: colors,
          width: 300,
        );
        expect(find.text('Queued (1)'), findsOneWidget);
        expect(find.text('Check the latest changes'), findsNothing);
      },
    );
  }

  testWidgets('long queues remain bounded and can scroll to the last message', (
    tester,
  ) async {
    final messages = List.generate(
      20,
      (index) => MessageEntity(
        chatId: 1,
        role: 'user',
        content: 'Queued request $index',
      ),
    );
    await pumpQueue(tester, messages, width: 340);
    expect(tester.getSize(find.byType(QueuedMessages)).height, lessThan(180));
    await tester.scrollUntilVisible(find.text('Queued request 19'), 100);
    expect(find.text('Queued request 19').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
