import 'dart:async';

import 'package:athena_gui/component/chat_column.dart';
import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/message_context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/turn_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/component/sentinel_placeholder.dart';
import 'package:athena_gui/util/chat_turn_util.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/component/elicit_card.dart';
import 'package:athena_gui/component/permission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageList extends StatefulWidget {
  final MessageListScrollController? controller;
  final void Function(MessageEntity message) onResend;
  const DesktopMessageList({
    super.key,
    this.controller,
    required this.onResend,
  });

  @override
  State<DesktopMessageList> createState() => _DesktopMessageListState();
}

class _DesktopMessageListState extends State<DesktopMessageList> {
  static const double _loadOlderThreshold = 120;

  /// 轮次指示器离消息区左缘的距离。
  static const double _turnIndicatorLeft = 12;

  /// 单条最大宽度。
  static const double _maxBarWidth = 20;

  /// 可用留白窄于这个值时干脆不显示指示器：定宽列被挤到窗口边缘时，
  /// 条会压到正文上。
  static const double _minBarWidth = 12;

  /// 点了窗口外那一轮时，最多向上翻几页去把它补进窗口。
  static const int _maxTurnJumpPages = 8;

  late final ChatViewModel chatViewModel;
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  final turnNavigator = TurnNavigator();
  int? _displayedChatId;

  @override
  void initState() {
    super.initState();
    chatViewModel = GetIt.instance<ChatViewModel>();
  }

  @override
  void dispose() {
    turnNavigator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      // 信号一律在这里读取。LayoutBuilder 的 builder 在布局阶段执行，
      // 不在 Watch 的依赖追踪范围内：在那里读信号不会订阅，审批/提问
      // 列表的变化就不会触发重建，卡片只能搭消息流下一次更新的车才
      // 出现或消失。
      final messages = chatViewModel.messages.value;
      final loading = chatViewModel.isCurrentChatStreaming.value;
      final loadingHistory = chatViewModel.isLoadingMessages.value;
      final chatId = chatViewModel.currentChat.value?.id;
      // 整段会话的轮次起点（整文件扫描，可能比首屏晚到）：读在 Watch 里才
      // 订阅得到，扫完指示器随之重画。
      final allTurnIds = chatViewModel.turnStartIds.value;
      final sentinel = _displaySentinel();
      // 当前对话挂起的权限审批卡片（非模态，随会话渲染）
      final approvals = chatViewModel.pendingApprovals.value
          .where((r) => r.chatId == chatId)
          .toList();
      // 当前对话挂起的提问卡片（同一归属规则，排在审批卡片之后）
      final elicits = chatViewModel.pendingElicits.value
          .where((r) => r.chatId == chatId)
          .toList();

      widget.controller?.isWorking = loading;
      if (_displayedChatId != chatId) {
        _displayedChatId = chatId;
        widget.controller?.followBottom();
      } else {
        widget.controller?.maintainBottom();
      }

      // 返回结构必须与「有无审批」无关：根控件类型一旦随审批状态变化，滚动视图
      // 及其 ScrollPosition 会被整体重建，新 position 从偏移 0（列表顶部）
      // 起步，贴底校正要晚一帧才生效，表现为卡片弹出时列表先跳到顶部再跳回底部。
      //
      // LayoutBuilder 只做一件事：把约束换算成列宽留白与卡片最大高度。
      return LayoutBuilder(
        builder: (context, constraints) {
          final columnPadding = chatColumnPadding(constraints.maxWidth);
          final cardMaxHeight =
              constraints.maxHeight * permissionCardMaxHeightFraction;
          final cardPadding = EdgeInsets.fromLTRB(
            columnPadding + kChatColumnInnerPadding,
            0,
            columnPadding + kChatColumnInnerPadding,
            12,
          );
          // 轮次指示器只占消息区左留白：条长上限随留白收缩，留白不够就不显示
          final barWidth = (columnPadding - _turnIndicatorLeft - 12).clamp(
            0.0,
            _maxBarWidth,
          );
          final turns = buildChatTurns(messages);
          // 条数 = 整段会话的 user 消息数（扫描结果，与窗口无关）；窗口只决定
          // 哪几条能 hover/预览，以及它们摆在整段的第几位（见 windowFirstTurnIndex）。
          // 计数还没到手时 turnIds 为空 → 不画，避免先给一个错的数字。
          final totalTurns = allTurnIds.length;
          final firstTurnIndex = windowFirstTurnIndex(allTurnIds, turns);
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildList(
                        messages,
                        loading: loading,
                        loadingHistory: loadingHistory,
                        sentinel: sentinel,
                        columnPadding: columnPadding,
                      ),
                    ),
                    // 一条 = 一轮（按整段会话算，含未加载的历史）；只有一轮时
                    // 不显示，单根条说明不了什么
                    if (!loadingHistory &&
                        totalTurns >= 2 &&
                        barWidth >= _minBarWidth)
                      Positioned(
                        left: _turnIndicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: barWidth,
                        child: Center(
                          child: TurnIndicator(
                            turns: turns,
                            navigator: turnNavigator,
                            maxBarWidth: barWidth,
                            totalTurns: totalTurns,
                            firstTurnIndex: firstTurnIndex,
                            onTurnSelected: _selectTurn,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final request in approvals)
                Padding(
                  padding: cardPadding,
                  child: PermissionApprovalCard(
                    request: request,
                    maxHeight: cardMaxHeight,
                    onDecision: (approved, persistExact) =>
                        chatViewModel.respondApproval(
                          request,
                          permissionDecisionOf(approved, persistExact),
                        ),
                  ),
                ),
              for (final request in elicits)
                Padding(
                  padding: cardPadding,
                  child: ElicitCard(
                    request: request,
                    maxHeight: cardMaxHeight,
                    onSubmit: (answers) =>
                        chatViewModel.respondElicit(request, answers),
                  ),
                ),
            ],
          );
        },
      );
    });
  }

  void copyMessage(MessageEntity message) {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  Future<void> destroyMessage(MessageEntity message) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this message?',
    );
    if (result == true) {
      await chatViewModel.deleteMessage(message);
    }
  }

  void openContextMenu(TapUpDetails details, MessageEntity message) {
    var contextMenu = DesktopMessageContextMenu(
      offset: details.globalPosition,
      onCopied: () => copyMessage(message),
      onDestroyed: () => destroyMessage(message),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification is! ScrollUpdateNotification ||
        (notification.scrollDelta ?? 0) >= 0 ||
        notification.metrics.extentBefore > _loadOlderThreshold ||
        !chatViewModel.hasOlderMessages) {
      return false;
    }

    final controller = widget.controller;
    if (controller == null) {
      unawaited(chatViewModel.loadOlderMessages());
    } else {
      unawaited(
        controller.preservePositionWhilePrepending(
          chatViewModel.loadOlderMessages,
        ),
      );
    }
    return false;
  }

  /// 点了第 [absoluteTurnIndex] 轮（整段会话下标）。
  ///
  /// 已经在窗口里就直接滚过去；在窗口之前（更早、还没加载）就先向上翻页，直到
  /// 那一轮进窗口再滚——否则点了没有任何反应。翻页有上限，到头（没有更早的
  /// 历史）也停下，避免点到一个已不存在的轮次后一直翻。
  Future<void> _selectTurn(int absoluteTurnIndex) async {
    for (var attempt = 0; attempt <= _maxTurnJumpPages; attempt++) {
      final windowTurns = buildChatTurns(chatViewModel.messages.value);
      final windowIndex =
          absoluteTurnIndex -
          windowFirstTurnIndex(chatViewModel.turnStartIds.value, windowTurns);
      if (windowIndex >= 0 && windowIndex < windowTurns.length) {
        turnNavigator.scrollToTurn(windowIndex);
        return;
      }
      // 比窗口还新（正常不会发生）或没有更早的历史了：停下
      if (windowIndex >= 0 || !chatViewModel.hasOlderMessages) return;
      final added = await chatViewModel.loadOlderMessages();
      if (added <= 0) return;
    }
  }

  SentinelEntity _displaySentinel() {
    if (chatViewModel.currentChat.value?.hasSentinel == false ||
        chatViewModel.currentSentinel.value?.id ==
            SentinelViewModel.directChatSentinel.id) {
      return SentinelViewModel.directChatSentinel;
    }
    return chatViewModel.currentSentinel.value ??
        sentinelViewModel.defaultSentinel.value;
  }

  /// 消息列表本体：空会话显示角色占位，否则是带懒加载的滚动列表。
  /// 只接收 build 阶段读好的值，自己不碰信号。
  ///
  /// **历史加载期间也要保留这条滚动视图**（[loadingHistory] 为真时只是不给
  /// sliver），只有"确实是空会话"才换成占位控件。原因：`selectChat` 是先把
  /// messages 清空、置 isLoadingMessages 再回填，若此时把整棵 CustomScrollView
  /// 摘掉，它的 ScrollPosition 会被销毁——新 position 的首帧没有尺寸，
  /// `correctForNewDimensions` 那条同帧贴底校正不会被调用（见
  /// `_MessageListScrollPosition`），于是这一帧按偏移 0（列表顶部）画出来，
  /// 贴底只剩 post-frame 的 jumpTo，晚一帧才生效，表现为切会话时列表先闪一下
  /// 新会话的开头再跳到底部。空会话没有可滚动内容，换掉它不会丢位置。
  Widget _buildList(
    List<MessageEntity> messages, {
    required bool loading,
    required bool loadingHistory,
    required SentinelEntity sentinel,
    required double columnPadding,
  }) {
    if (messages.isEmpty && !loadingHistory) {
      return SentinelPlaceholder(sentinel: sentinel);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: widget.controller?.handleMetricsNotification,
        child: CustomScrollView(
          controller: widget.controller,
          slivers: [
            if (!loadingHistory)
              MessageCardListSliver(
                messages: messages,
                loading: loading,
                sentinel: sentinel,
                navigator: turnNavigator,
                // 消息列与 composer 用同一条 768 定宽列并左缘对齐；
                // 列内的左右留白由各消息自己带（助手 4 / 用户 12），
                // 这里再加内边距会让正文比 Claude 右移 24。
                padding: EdgeInsets.symmetric(
                  horizontal: columnPadding,
                  vertical: 12,
                ),
                onResend: widget.onResend,
                onSecondaryTapUp: openContextMenu,
              ),
          ],
        ),
      ),
    );
  }
}
