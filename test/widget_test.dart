import 'package:flutter_test/flutter_test.dart';

import 'package:athena/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AthenaApp());

    expect(find.text('Athena'), findsOneWidget);
  });
}
