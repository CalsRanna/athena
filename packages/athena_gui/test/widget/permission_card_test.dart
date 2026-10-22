import 'dart:async';

import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_gui/component/permission_card.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/athena_test_scope.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/theme/athena_theme.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('${platform.name} 审批卡共用工具图标且审批按钮可用', (tester) async {
      const toolName = 'experience_recall';
      final theme = buildAthenaThemeData(
        AthenaColorMode.light,
      ).copyWith(platform: platform);
      bool? decision;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => AthenaTestScope(child: child!),
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
                  onDecision: (approved) {
                    decision = approved;
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
      expect(icon.size, 16);
      expect(icon.color, colorsOf(AthenaColorMode.light).textPrimary);
      expect(find.text(toolName), findsOneWidget);
      expect(find.text('回忆项目约定'), findsOneWidget);
      expect(find.textContaining('query: project rules'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Allow'));
      expect(decision, isTrue);
      expect(find.text('Always Allow'), findsNothing);
      await tester.tap(find.text('Deny'));
      expect(decision, isFalse);
    });
  }

  testWidgets('审批卡默认展开，点标题行收起为一行，再点恢复', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: PermissionApprovalCard(
                request: ApprovalRequest(
                  chatId: 'chat-1',
                  toolName: 'file_read',
                  arguments: '{"path":"/tmp/config.json"}',
                  completer: Completer<PermissionDecision>(),
                ),
                maxHeight: 400,
                onDecision: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final expandedHeight = tester
        .getSize(find.byType(PermissionApprovalCard))
        .height;
    // 标题行是整行宽的可点区域，不能带按压缩放：0.975 落在几百像素宽的一行上
    // 是明显的横向收缩，内容会离开卡片内边距，看起来像箭头在抖。
    expect(
      find.ancestor(
        of: find.text('file_read'),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );
    expect(find.text('path: /tmp/config.json'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);

    await tester.tap(find.text('file_read'));
    await tester.pumpAndSettle();
    expect(find.text('file_read'), findsOneWidget);
    expect(find.text('Needs your approval'), findsOneWidget);
    expect(find.text('path: /tmp/config.json'), findsNothing);
    expect(find.text('Allow'), findsNothing);
    expect(
      tester.getSize(find.byType(PermissionApprovalCard)).height,
      lessThan(expandedHeight),
    );

    await tester.tap(find.text('file_read'));
    await tester.pumpAndSettle();
    expect(find.text('path: /tmp/config.json'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('审批标题缺少描述时用审批占位，完整参数仍在详情中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: PermissionApprovalCard(
            request: ApprovalRequest(
              chatId: 'chat-1',
              toolName: 'file_read',
              arguments: '{"path":"/tmp/config.json"}',
              completer: Completer<PermissionDecision>(),
            ),
            maxHeight: 400,
            onDecision: (_) {},
          ),
        ),
      ),
    );

    final header = find
        .ancestor(of: find.text('file_read'), matching: find.byType(Row))
        .first;
    final headerTexts = tester.widgetList<Text>(
      find.descendant(of: header, matching: find.byType(Text)),
    );
    expect(headerTexts.map((text) => text.data), [
      'file_read',
      'Needs your approval',
    ]);
    expect(find.text('path: /tmp/config.json'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
