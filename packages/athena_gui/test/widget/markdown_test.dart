import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/athena_test_scope.dart';

void main() {
  Future<void> showMarkdown(WidgetTester tester, AthenaMarkdown child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AthenaMaterialTheme.buildAthenaThemeData(AthenaColorMode.light),
        builder: (_, child) => AthenaTestScope(child: child!),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('plain content does not interpret message-only markup', (
    tester,
  ) async {
    await showMarkdown(
      tester,
      const AthenaMarkdown(
        content:
            'Instruction [[1]].\n\n'
            '<CallToolRequest name="legacy" arguments="{}"></CallToolRequest>',
      ),
    );
    expect(find.textContaining('[[1]]', findRichText: true), findsWidgets);
    expect(find.text('1'), findsNothing);
    expect(find.text('Call tool: legacy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('references and ordinary links open their respective URLs', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final opened = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        opened.add((call.arguments as Map<Object?, Object?>)['url']! as String);
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await showMarkdown(
      tester,
      const AthenaMarkdown(
        content: 'Source [[1]].\n\n[Documentation](https://example.com/docs)',
        reference: '[{"url":"https://example.com/source"}]',
      ),
    );

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documentation', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened, ['https://example.com/source', 'https://example.com/docs']);
    expect(tester.takeException(), isNull);
  });
}
