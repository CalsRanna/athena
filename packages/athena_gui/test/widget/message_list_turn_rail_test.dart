import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/chat_preview_card.dart';
import 'package:athena_gui/page/desktop/home/component/message_list.dart';
import 'package:athena_gui/page/desktop/home/component/turn_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 工作区里轮次条的两条硬要求（都在 `DesktopMessageList` 这一层成立，
/// 单测 `TurnIndicator` 覆盖不到）：
///
/// 1. **agent 工作期间不跟着重绘**。工作区由 `Watch` 驱动，流式时每帧重建；
///    轮次条的**内容**（每轮正文）每帧都在变，但**结构**（几条、窗口摆在哪、
///    多宽）不变。宿主只把结构交给控件、按结构缓存控件实例，内容留到 hover
///    现取——于是这棵子树不重建、也就不重绘。判据取「控件实例是否复用」：
///    它是重绘的**因**（配置变了才会重建，重建才传导出绘制脏标记；外面单包
///    `RepaintBoundary` 挡不住，实测加了边界仍每帧重绘）。
/// 2. **审批 / 提问卡片弹出时位置不变**。卡片挤占的是消息区的高度，而轮次条
///    排在整列高度里居中——它不该按消息区（会变矮的那块）居中。
void main() {
  late Directory tempRoot;
  late ChatViewModel viewModel;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_turn_rail_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<ChatViewModel>();
    await viewModel.selectChat(
      ChatEntity(
        id: 'chat-1',
        title: 'probe',
        modelId: '1',
        sentinelId: ChatEntity.noSentinelId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  /// 六轮会话：窗口与整段会话重合（无分页、无未加载历史）。
  void seedTurns() {
    viewModel.messages.value = [
      for (var i = 0; i < 6; i++) ...[
        MessageEntity(
          id: '${i * 2}',
          chatId: 'chat-1',
          role: 'user',
          content: 'user $i',
        ),
        MessageEntity(
          id: '${i * 2 + 1}',
          chatId: 'chat-1',
          role: 'assistant',
          content: 'answer $i ${'detail ' * (1 + i % 4)}',
        ),
      ],
    ];
    viewModel.turnStartIds.value = [for (var i = 0; i < 6; i++) '${i * 2}'];
  }

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: DesktopMessageList(controller: null, onRewind: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  TurnIndicator rail(WidgetTester tester) =>
      tester.widget<TurnIndicator>(find.byType(TurnIndicator));

  /// 流式追加：最后一轮的助手正文每帧变长，轮数不动（结构不变）。
  Future<void> streamTail(WidgetTester tester, {int frames = 5}) async {
    for (var i = 0; i < frames; i++) {
      viewModel.messages.value = [
        ...viewModel.messages.value.take(11),
        MessageEntity(
          id: '11',
          chatId: 'chat-1',
          role: 'assistant',
          content: 'answer 5 ${'tok ' * (i + 1)}',
        ),
      ];
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('流式刷新（内容变、结构不变）复用控件实例，轮次变化才重建', (tester) async {
    seedTurns();
    await pumpList(tester);

    final first = rail(tester);
    await streamTail(tester);

    // 结构没变 → 实例复用：不重建，也就不会每帧重绘
    expect(identical(rail(tester), first), isTrue);

    // 整段会话多出一轮（结构变了）→ 重建是该的，不能一直拿旧的那棵
    viewModel.turnStartIds.value = [for (var i = 0; i < 7; i++) '${i * 2}'];
    await tester.pump(const Duration(milliseconds: 16));
    expect(identical(rail(tester), first), isFalse);
  });

  testWidgets('审批卡与提问卡弹出时轮次条位置不变', (tester) async {
    seedTurns();
    await pumpList(tester);

    final before = tester.getRect(find.byType(TurnIndicator));

    viewModel.pendingApprovals.value = [
      ApprovalRequest(
        chatId: 'chat-1',
        toolName: 'bash',
        arguments: '{"command":"ls"}',
        completer: Completer<PermissionDecision>(),
      ),
    ];
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byType(TurnIndicator)), before);

    viewModel.pendingElicits.value = [
      ElicitRequest(
        chatId: 'chat-1',
        questions: const [
          ElicitQuestion(
            question: 'Which one?',
            header: 'pick',
            options: [
              ElicitOption(label: 'a', description: 'first'),
              ElicitOption(label: 'b', description: 'second'),
            ],
          ),
        ],
        completer: Completer<Map<String, String>?>(),
      ),
    ];
    await tester.pump(const Duration(milliseconds: 16));
    // 位置取的是整列高度，卡片挤占的是消息区那一块，与条无关
    expect(tester.getRect(find.byType(TurnIndicator)), before);
  });

  testWidgets('卡片堆多张、再清空，轮次条都用整列高度居中', (tester) async {
    seedTurns();
    await pumpList(tester);

    final before = tester.getRect(find.byType(TurnIndicator));

    // 卡片一路堆到超出消息区：旧写法（条按消息区高度居中）会先被压扁到
    // 几像素、再被挤成零高（条整列消失），这里要求它自始至终不动
    viewModel.pendingApprovals.value = [
      for (var i = 0; i < 4; i++)
        ApprovalRequest(
          chatId: 'chat-1',
          toolName: 'bash',
          arguments: '{"command":"ls $i"}',
          completer: Completer<PermissionDecision>(),
        ),
    ];
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byType(TurnIndicator)), before);

    viewModel.pendingApprovals.value = [];
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byType(TurnIndicator)), before);
  });

  testWidgets('预览卡取的是当前内容（内容不进控件配置）', (tester) async {
    seedTurns();
    await pumpList(tester);
    // 先把最后一轮正文改掉：预览要反映的是改后的内容
    const latest = 'answer 5 rewritten by the probe';
    viewModel.messages.value = [
      ...viewModel.messages.value.take(11),
      MessageEntity(
        id: '11',
        chatId: 'chat-1',
        role: 'assistant',
        content: latest,
      ),
    ];
    await tester.pump(const Duration(milliseconds: 16));

    // 停在页内最后一条的中线（条列左缘往内 5px）
    final bounds = tester.getRect(find.byType(TurnIndicator));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      Offset(bounds.left + 5, bounds.top + 5.5 * bounds.height / 6),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final card = tester.widget<ChatPreviewCard>(find.byType(ChatPreviewCard));
    expect(card.answer, latest);
  });
}
