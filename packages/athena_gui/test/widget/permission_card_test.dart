import 'dart:async';

import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/widget/permission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ApprovalRequest makeRequest() => ApprovalRequest(
        chatId: 1,
        toolName: 'sentinel_evolve',
        arguments: 'sentinel_name: Athena\nimprovements: ...',
        completer: Completer<PermissionDecision>(),
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required TargetPlatform platform,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          platform: platform,
          extensions: [AthenaColors.dark],
        ),
        home: Scaffold(body: PermissionApprovalCard(
          request: makeRequest(),
          onDecision: (_, __) {},
        )),
      ),
    );
  }

  double buttonWidth(WidgetTester tester, String label) {
    return tester
        .getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(GestureDetector),
          ).first,
        )
        .width;
  }

  testWidgets('移动端三个审批按钮等宽拉伸并文字居中', (tester) async {
    await pumpCard(tester, platform: TargetPlatform.iOS);

    final allowOnce = buttonWidth(tester, 'Allow Once');
    final alwaysAllow = buttonWidth(tester, 'Always Allow');
    final deny = buttonWidth(tester, 'Deny');

    // 三个按钮同宽（stretch）
    expect(allowOnce, alwaysAllow);
    expect(alwaysAllow, deny);
    // 按钮撑满卡片内容宽度（测试面宽 800，内容区约 716）
    expect(deny, greaterThan(600));

    // 文字在按钮内水平居中
    final denyButton = find
        .ancestor(
          of: find.text('Deny'),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.getCenter(find.text('Deny')).dx,
        closeTo(tester.getCenter(denyButton).dx, 1.0));
  });

  testWidgets('桌面端三个按钮保持行内紧凑布局', (tester) async {
    await pumpCard(tester, platform: TargetPlatform.macOS);

    final deny = buttonWidth(tester, 'Deny');
    // 桌面端按钮按内容宽度收缩，不撑满卡片
    expect(deny, lessThan(200));
  });
}
