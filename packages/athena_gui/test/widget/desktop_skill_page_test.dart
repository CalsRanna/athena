import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/setting/skill/skill_page.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/athena_test_scope.dart';

void main() {
  late Directory home;
  late SkillRegistry registry;

  setUp(() {
    home = Directory.systemTemp.createTempSync('athena-skill-page');
    registry = SkillRegistry()..loadAll(homeDir: home.path);
    for (final (name, day) in [('alpha', 1), ('zulu', 9)]) {
      final directory = '${registry.skillsDirectory}/$name';
      SkillLoader().saveSkill(
        name: name,
        description: 'Review $name changes',
        body: '# Steps',
        targetDir: directory,
      );
      File('$directory/SKILL.md').setLastModifiedSync(DateTime(2026, 3, day));
    }
    registry.registerBuiltin(
      const Skill(
        name: 'experience',
        description: 'Recall prior work',
        body: '# Recall',
        sourcePath: '(builtin)',
      ),
    );
    GetIt.instance.registerSingleton(SkillViewModel(skillRegistry: registry));
  });

  tearDown(() async {
    DesktopContextMenuManager.instance.dismiss();
    await GetIt.instance.reset();
    home.deleteSync(recursive: true);
  });

  Future<void> showPage(WidgetTester tester, {double width = 820}) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: router.navigatorKey,
        theme: buildAthenaThemeData(AthenaColorMode.light)
            .copyWith(platform: TargetPlatform.macOS),
        builder: (_, child) => AthenaTestScope(child: child!),
        home: const Material(child: DesktopSettingSkillPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search, source and sort use the visible skill groups', (
    tester,
  ) async {
    await showPage(tester, width: 440);
    double rowY(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(rowY('zulu'), lessThan(rowY('alpha')));
    expect(find.text('Mar 9'), findsOneWidget);

    await tester.tap(find.byTooltip('Sort by Last edited'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(rowY('alpha'), lessThan(rowY('zulu')));

    await tester.enterText(find.byType(TextField), 'REVIEW');
    await tester.pumpAndSettle();
    expect(find.text('experience'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter by source: All sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Built-in'));
    await tester.pumpAndSettle();
    expect(find.text('No matching skills'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsNothing);
    await tester.tap(find.text('experience'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AthenaMarkdown>(find.byType(AthenaMarkdown)).content,
      '# Recall',
    );
    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();
    expect(find.text('experience'), findsOneWidget);
    expect(find.text('Your skills'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview uses shared code block copying and supports text selection',
    (tester) async {
      await GetIt.instance<SkillViewModel>().createSkill(
        name: 'code-example',
        description: 'Preview code',
        body: 'Select this instruction.\n\n```dart\nprint(42);\n```',
      );
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await showPage(tester);
      await tester.tap(find.text('code-example'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('markdown-code-block')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(AthenaMarkdown),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(copied, 'print(42);');
      await tester.pump(AthenaMotion.linger);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview shows the draft, save persists it and discard restores it',
    (tester) async {
      await showPage(tester);
      await tester.tap(find.byTooltip('More actions for alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '# Revised');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AthenaMarkdown>(find.byType(AthenaMarkdown)).content,
        '# Revised',
      );
      expect(registry.all.firstWhere((s) => s.name == 'alpha').body, '# Steps');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AthenaMarkdown>(find.byType(AthenaMarkdown)).content,
        '# Steps',
      );

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '# Saved');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(AthenaMotion.linger);
      registry.reload();
      expect(registry.all.firstWhere((s) => s.name == 'alpha').body, '# Saved');
      expect(find.text('Save'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
