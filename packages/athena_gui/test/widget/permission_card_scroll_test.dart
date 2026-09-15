import 'dart:async';

import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_gui/page/desktop/home/component/message_list.dart';
import 'package:athena_gui/page/mobile/chat/chat.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../test_utils/fakes.dart';

/// 审批卡片弹出时不得移动消息列表的滚动位置。
///
/// 回归：`_buildData` 曾按「有无审批」返回不同的根控件类型（裸滚动视图 vs
/// LayoutBuilder），类型变化会销毁重建整个滚动视图与其 ScrollPosition，新
/// position 从偏移 0（列表顶部）起步，贴底校正排在其后一帧的 post-frame
/// 回调里，表现为卡片弹出时列表先跳到顶部再跳回底部。
///
/// 判定方式：探针在构建该帧**之前**注册 post-frame 回调，因而排在控制器
/// 内部 `maintainBottom()` 的回调之前执行，读到的是该帧真正绘制出来的偏移；
/// 若只断言 `controller.offset`，同一次 pump 内的校正会掩盖这一帧的闪烁。
void main() {
  /// 桌面平台才插入纵向 Scrollbar，而该闪烁与它相关，故测试固定用桌面主题。
  Widget wrapDesktopApp(Widget child) => MaterialApp(
    home: Scaffold(body: child),
    theme: ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.windows,
      extensions: [AthenaColors.dark],
    ),
  );

  late ChatViewModel chatViewModel;
  late SentinelViewModel sentinelViewModel;

  setUp(() {
    setupMobileTestDI();
    chatViewModel = GetIt.instance<ChatViewModel>();
    sentinelViewModel = GetIt.instance<SentinelViewModel>();
  });

  List<MessageEntity> buildMessages() => [
    for (var i = 0; i < 40; i++)
      MessageEntity(
        id: i + 1,
        chatId: 1,
        role: i.isEven ? 'user' : 'assistant',
        content: '消息 $i, ${'内容片段 ' * (1 + i % 4)}',
      ),
  ];

  ApprovalRequest buildRequest() => ApprovalRequest(
    chatId: 1,
    toolName: 'shell',
    arguments: '{"command":"ls"}',
    completer: Completer<PermissionDecision>(),
  );

  testWidgets('桌面：审批卡片弹出那一帧消息列表仍贴底', (tester) async {
    final chat = testChat(id: 1, title: 'C');
    sentinelViewModel.sentinels.value = [testSentinel(name: 'Athena')];
    chatViewModel.currentChat.value = chat;

    final controller = MessageListScrollController();
    await tester.pumpWidget(
      wrapDesktopApp(
        SizedBox(
          height: 600,
          child: DesktopMessageList(controller: controller, onResend: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    chatViewModel.messages.value = buildMessages();
    await tester.pumpAndSettle();
    controller.followBottom();
    await tester.pumpAndSettle();
    expect(
      controller.position.maxScrollExtent - controller.offset,
      lessThan(1),
      reason: '前置条件：列表初始应停在底部',
    );

    var painted = -1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) painted = controller.offset;
    });
    chatViewModel.pendingApprovals.value = [buildRequest()];
    await tester.pump();

    expect(
      controller.position.maxScrollExtent - painted,
      lessThan(1),
      reason: '卡片弹出那一帧就应贴底，而不是停在列表顶部',
    );
    // 卡片消失（决策完成）同样不得移动列表
    var paintedAfterRemoval = -1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) paintedAfterRemoval = controller.offset;
    });
    chatViewModel.pendingApprovals.value = [];
    await tester.pump();
    expect(
      controller.position.maxScrollExtent - paintedAfterRemoval,
      lessThan(1),
      reason: '卡片消失那一帧也应贴底',
    );
  });

  testWidgets('移动：审批卡片弹出那一帧消息列表仍贴底', (tester) async {
    final chat = testChat(id: 1, title: 'C');
    sentinelViewModel.sentinels.value = [testSentinel(name: 'Athena')];
    chatViewModel.currentChat.value = chat;

    await tester.pumpWidget(wrapDesktopApp(MobileChatPage(chat: chat)));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 页面 initSignals 的异步初始化会清空消息，注入必须在它之后
    chatViewModel.messages.value = buildMessages();
    await tester.pumpAndSettle();

    final controller =
        tester
                .widgetList<CustomScrollView>(find.byType(CustomScrollView))
                .first
                .controller!
            as MessageListScrollController;
    controller.followBottom();
    await tester.pumpAndSettle();
    expect(
      controller.position.maxScrollExtent - controller.offset,
      lessThan(1),
      reason: '前置条件：列表初始应停在底部',
    );

    var painted = -1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) painted = controller.offset;
    });
    chatViewModel.pendingApprovals.value = [buildRequest()];
    await tester.pump();

    expect(
      controller.position.maxScrollExtent - painted,
      lessThan(1),
      reason: '卡片弹出那一帧就应贴底，而不是停在列表顶部',
    );
  });
}
