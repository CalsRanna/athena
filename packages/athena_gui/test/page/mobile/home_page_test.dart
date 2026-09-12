import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/page/mobile/home/home.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
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

  });

  group('MobileHomePage with data', () {
    testWidgets('shows sentinel tiles when sentinels exist', (tester) async {
      final sentinel = testSentinel(name: 'Athena');
      sentinelViewModel.sentinels.value = [sentinel];

      await pumpHomePage(tester);

      expect(find.text('Athena'), findsOneWidget);
    });

    testWidgets('does not display skills on the home page', (
      tester,
    ) async {
      await pumpHomePage(tester);
      GetIt.instance<SkillViewModel>().skills.value = [
        const Skill(
          name: 'demo-skill',
          description: 'A demo skill',
          body: 'body',
          sourcePath: '/tmp/demo-skill',
        ),
      ];
      await tester.pumpAndSettle();

      expect(find.text('demo-skill'), findsNothing);
      expect(find.text('Skills'), findsNothing);
      expect(find.text('Skills & Experiences'), findsNothing);
    });

    testWidgets('shows Experiences title with empty data', (
      tester,
    ) async {
      await pumpHomePage(tester);

      expect(find.text('Experiences'), findsOneWidget);
      expect(find.text('Skills & Experiences'), findsNothing);
    });

    testWidgets('shows experience cards on the home page', (
      tester,
    ) async {
      await pumpHomePage(tester);
      GetIt.instance<ExperienceViewModel>().experiences.value = [
        ExperienceEntity(
          id: 'e1',
          createdAt: DateTime(2026, 9, 1),
          lesson: 'Prefer re-reading files before editing',
          sentinelId: '7',
        ),
      ];
      await tester.pumpAndSettle();

      expect(
        find.text('Prefer re-reading files before editing'),
        findsOneWidget,
      );
    });
  });
}
