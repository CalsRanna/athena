import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_tiles.dart';
import 'package:athena_gui/page/mobile/chat/component/send_button.dart';
import 'package:athena_gui/page/mobile/chat/component/user_input.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
import 'package:athena_gui/page/mobile/component/grid_tile.dart';
import 'package:athena_gui/page/mobile/home/component/card_tile.dart';
import 'package:athena_gui/page/mobile/home/component/new_chat_button.dart';
import 'package:athena_gui/page/mobile/setting/component/section.dart';
import 'package:athena_gui/page/mobile/setting/component/setting_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/checkbox.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _app(
  Widget child, {
  double width = 320,
  double scale = 2,
  TargetPlatform platform = TargetPlatform.iOS,
}) {
  return MaterialApp(
    theme: buildAthenaThemeData(
      AthenaColorMode.light,
    ).copyWith(platform: platform),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 700),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('bottom sheet tile ellipsizes long title and trailing at 2x', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AthenaBottomSheetTile(
          leading: const Icon(Icons.abc),
          title: 'A quite long bottom sheet title that should ellipsize',
          trailing: const Text('A long trailing value'),
          onTap: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings section fits grouped rows at 2x', (tester) async {
    await tester.pumpWidget(
      _app(
        MobileSettingsSection(
          title: 'Assistant',
          description: 'How the agent runs and which model it uses.',
          children: [
            MobileSettingTile(
              leading: const Icon(Icons.abc),
              title: 'Default models',
              subtitle: 'Model used for new sessions and naming',
              trailing: '',
              onTap: () {},
            ),
            MobileSettingTile(
              leading: const Icon(Icons.abc),
              title: 'Providers',
              subtitle: 'API keys and model catalog',
              trailing: 'System',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home card grows instead of overflowing at 2x', (tester) async {
    await tester.pumpWidget(
      _app(
        const CardTile(
          icon: Icons.abc,
          name: 'A quite long experience lesson title that wraps',
          description: 'A long description that should not overflow the card',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile canvas uses the workspace surface', (tester) async {
    final colors = colorsOf(AthenaColorMode.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(
          AthenaColorMode.dark,
        ).copyWith(platform: TargetPlatform.iOS),
        home: const AthenaScaffold(body: SizedBox()),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == colors.surface,
      ),
      findsOneWidget,
    );
  });

  testWidgets('grid tiles use neutral surfaces and normal text', (
    tester,
  ) async {
    final colors = colorsOf(AthenaColorMode.light);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          child: MobileGridTile(
            title: 'Skill',
            subtitle: 'Description',
            onTap: () {},
          ),
        ),
        scale: 1,
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                colors.surfaceButtonSecondary,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('Skill')).style!.color,
      colors.textPrimary,
    );
  });

  testWidgets('grid tile keeps long text inside the card at 2x', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          child: MobileGridTile(
            title: 'A quite long skill title that should wrap',
            subtitle: 'A long description that should wrap over several lines',
            titleMaxLines: 3,
            subtitleMaxLines: 2,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state keeps its action inside the viewport at 2x', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MobileEmptyState(
          icon: Icons.abc,
          title: 'No sessions yet',
          hint: 'Start a new session and it will show up here.',
          action: AthenaPrimaryButton(
            onTap: () {},
            child: const Text('New Session'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home new session button is a full-width 48 target', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const NewChatButton()));
    final size = tester.getSize(find.byType(NewChatButton));
    expect(size.height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile send button has a 48 touch target', (tester) async {
    await tester.pumpWidget(
      _app(SendButton(isStreaming: false, onSubmitted: () {})),
    );
    expect(tester.getSize(find.byType(SendButton)), const Size(48, 48));
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('icon buttons use a neutral surface on ${platform.name}', (
      tester,
    ) async {
      final colors = colorsOf(AthenaColorMode.light);
      await tester.pumpWidget(
        _app(
          AthenaIconButton(icon: Icons.more, onTap: () {}),
          scale: 1,
          platform: platform,
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(AthenaIconButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, colors.surfaceButtonSecondary);
      expect(decoration.border, isNotNull);
      final icon = tester.widget<Icon>(find.byIcon(Icons.more));
      expect(icon.color, colors.textPrimary);
    });
  }

  testWidgets('composer exposes an image picker', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var picked = 0;
    await tester.pumpWidget(
      _app(
        UserInput(
          controller: controller,
          isStreaming: false,
          onPickImages: () => picked++,
        ),
        scale: 1,
      ),
    );
    await tester.tap(find.byIcon(LucideIcons.paperclip));
    expect(picked, 1);
  });

  testWidgets('composer orders more, attach and send from left to right', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var moreTaps = 0;
    await tester.pumpWidget(
      _app(
        UserInput(
          controller: controller,
          isStreaming: false,
          onMore: () => moreTaps++,
        ),
        scale: 1,
      ),
    );
    final more = tester.getCenter(find.byIcon(AthenaIcons.more));
    final attach = tester.getCenter(find.byIcon(LucideIcons.paperclip));
    final send = tester.getCenter(find.byIcon(LucideIcons.arrowUp));
    expect(more.dx, lessThan(attach.dx));
    expect(attach.dx, lessThan(send.dx));
    await tester.tap(find.byIcon(AthenaIcons.more));
    expect(moreTaps, 1);
  });

  testWidgets('mobile switches and checkboxes get a 48 touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AthenaSwitch(value: false, onChanged: (_) {}),
            AthenaCheckbox(value: false, onChanged: (_) {}),
          ],
        ),
        scale: 1,
      ),
    );
    expect(tester.getSize(find.byType(AthenaSwitch)), const Size(48, 48));
    expect(tester.getSize(find.byType(AthenaCheckbox)), const Size(48, 48));
  });

  testWidgets('message actions are always visible on mobile', (tester) async {
    final message = MessageEntity(
      chatId: '1',
      role: 'user',
      content: 'A message',
    );
    await tester.pumpWidget(
      _app(
        MessageListTile(
          message: message,
          sentinel: const SentinelEntity(name: 'Athena'),
          onRewind: () {},
        ),
        scale: 1,
      ),
    );
    final bar = find.byType(MessageActionBar);
    expect(bar, findsOneWidget);
    final opacity = find.descendant(
      of: bar,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
  });
}
