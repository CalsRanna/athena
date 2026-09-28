import 'dart:async';

import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_gui/component/permission_card.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('${platform.name} 审批卡共用工具图标且审批按钮可用', (tester) async {
      const toolName = 'experience_recall';
      final theme = buildAthenaThemeData(
        AthenaColorMode.light,
      ).copyWith(platform: platform);
      (bool, bool)? decision;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: platform == TargetPlatform.android ? 390 : 640,
                child: PermissionApprovalCard(
                  request: ApprovalRequest(
                    chatId: 'chat-1',
                    toolName: toolName,
                    arguments:
                        '{"call_description":"回忆项目约定","query":"project rules"}',
                    completer: Completer<PermissionDecision>(),
                  ),
                  maxHeight: 400,
                  onDecision: (approved, persistExact) {
                    decision = (approved, persistExact);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(StepCard.toolIcon(toolName));
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 15);
      expect(icon.color, theme.extension<AthenaColors>()!.textPrimary);
      expect(find.text(toolName), findsOneWidget);
      expect(find.text('回忆项目约定'), findsOneWidget);
      expect(find.text('query: project rules'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Allow Once'));
      expect(decision, (true, false));
    });
  }

  testWidgets('审批标题缺少描述时用占位，完整参数仍在详情中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: PermissionApprovalCard(
            request: ApprovalRequest(
              chatId: 'chat-1',
              toolName: 'file_read',
              arguments: '{"path":"/tmp/config.json"}',
              completer: Completer<PermissionDecision>(),
            ),
            maxHeight: 400,
            onDecision: (_, _) {},
          ),
        ),
      ),
    );

    final header = find.ancestor(
      of: find.text('file_read'),
      matching: find.byType(Row),
    ).first;
    final headerTexts = tester.widgetList<Text>(
      find.descendant(of: header, matching: find.byType(Text)),
    );
    expect(headerTexts.map((text) => text.data), ['file_read', 'Using a tool']);
    expect(find.text('path: /tmp/config.json'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
