import 'package:athena/page/mobile/home/home.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../test_utils/fakes.dart';

void main() {
  late SentinelViewModel sentinelViewModel;

  setUp(() {
    setupMobileTestDI();
    sentinelViewModel = GetIt.instance<SentinelViewModel>();
    // Disable periodic visibility checks to prevent timer leaks in tests
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<void> pumpHomePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(wrapWithApp(const MobileHomePage()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  group('MobileHomePage rendering', () {
    testWidgets('shows greeting text', (tester) async {
      await pumpHomePage(tester);
      expect(find.textContaining('Good '), findsOneWidget);
    });

    testWidgets('shows New Chat button', (tester) async {
      await pumpHomePage(tester);
      expect(find.text('New Chat'), findsOneWidget);
    });

    testWidgets('shows Sentinel section title', (tester) async {
      await pumpHomePage(tester);
      expect(find.text('Sentinel'), findsOneWidget);
    });

    testWidgets('shows Shortcut section title', (tester) async {
      await pumpHomePage(tester);
      expect(find.text('Shortcut'), findsOneWidget);
    });
  });

  group('MobileHomePage with data', () {
    testWidgets('shows sentinel tiles when sentinels exist', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpHomePage(tester);

      expect(find.text('Athena'), findsOneWidget);
    });
  });
}
