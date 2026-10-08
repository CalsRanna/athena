import 'dart:async';

import 'package:athena_gui/page/desktop/home/component/chat_column.dart';
import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/message_context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/turn_indicator.dart';
import 'package:athena_gui/component/turn_navigator.dart';
import 'package:athena_gui/component/sentinel_placeholder.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/chat_turn_util.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/workspace_text_size.dart';
import 'package:athena_gui/component/elicit_card.dart';
import 'package:athena_gui/component/permission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageList extends StatefulWidget {
  final MessageListScrollController? controller;
  final void Function(MessageEntity message) onRewind;
  const DesktopMessageList({
    super.key,
    this.controller,
    required this.onRewind,
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
  String? _displayedChatId;

  /// 轮次条那棵子树**缓存下来的实例**，以及它当前对应的结构（见 [_railFor]）。
  ///
  /// 缓存的是「哪些东西会改变条列的结构与摆位」，正文内容不在其中——它由
  /// [TurnIndicator.turnAt] 现取（见 [_turnAt]），所以 agent 工作期间内容每帧
  /// 更新也不会让这棵子树重建、重绘。
  Widget? _rail;
  ({int windowTurnCount, int totalTurns, int firstTurnIndex, double barWidth})?
  _railKey;

  /// 窗口里每一轮的**当前**内容，供轮次条 hover 预览时现取。
  ///
  /// 与 [_railKey] 相反，它每帧都刷新：不进控件配置，只被回调读。
  List<ChatTurn> _windowTurns = const [];
  int _windowFirstTurnIndex = 0;

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
      final textSize = GetIt.instance<SettingViewModel>().textSize.value;
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

      final turns = buildChatTurns(messages);
      // 条数 = 整段会话的 user 消息数（扫描结果，与窗口无关）；窗口只决定
      // 哪几条能 hover/预览，以及它们摆在整段的第几位（见 windowFirstTurnIndex）。
      // 计数还没到手时 turnIds 为空 → 不画，避免先给一个错的数字。
      final totalTurns = allTurnIds.length;
      final firstTurnIndex = windowFirstTurnIndex(allTurnIds, turns);
      // 只给 hover 预览的回调现取用（见 [_turnAt]），**不进控件配置**——它每帧
      // 都在变，进配置就会让轮次条跟着每帧重建、重绘
      _windowTurns = turns;
      _windowFirstTurnIndex = firstTurnIndex;

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
          // 一条 = 一轮（按整段会话算，含未加载的历史）；只有一轮时不显示，
          // 单根条说明不了什么
          final showRail =
              !loadingHistory && totalTurns >= 2 && barWidth >= _minBarWidth;
          return Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildList(
                        messages,
                        loading: loading,
                        loadingHistory: loadingHistory,
                        sentinel: sentinel,
                        textSize: textSize,
                        columnPadding: columnPadding,
                      ),
                    ),
                    for (final request in approvals)
                      Padding(
                        padding: cardPadding,
                        child: PermissionApprovalCard(
                          request: request,
                          maxHeight: cardMaxHeight,
                          onDecision: (approved) =>
                              chatViewModel.respondApproval(
                                request,
                                permissionDecisionOf(approved),
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
                ),
              ),
              // 轮次条是上面那列的**兄弟**，不是它 Stack 里的孩子：`top: 0,
              // bottom: 0` 撑满的是整列高度，而这一高度与下面有几张审批 /
              // 提问卡片无关。放进消息区那个 Stack 里时它按消息区（Expanded）
              // 的高度居中，卡片一挤占，同一轮的条就整体上移——两帧之间换了位置。
              //
              // 它只占左留白那一小条，其余指针直接穿过去（见 TurnIndicator），
              // 所以叠在卡片上方不影响卡片操作。故意不包 IgnorePointer：条自己
              // 要能 hover 与点击。
              if (showRail)
                Positioned(
                  left: _turnIndicatorLeft,
                  top: 0,
                  bottom: 0,
                  width: barWidth,
                  child: Center(
                    child: _railFor(
                      windowTurnCount: turns.length,
                      totalTurns: totalTurns,
                      firstTurnIndex: firstTurnIndex,
                      barWidth: barWidth,
                    ),
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
    final chatId = chatViewModel.currentChat.value?.id;
    // 运行中删除会删掉正在运行的 run 的消息，run 随后的写入又把它们补回来
    if (chatId != null && chatViewModel.isStreamingChat(chatId)) {
      AthenaDialog.info('Please wait for the current session to finish.');
      return;
    }
    // 删除会连带删掉这条之后的全部消息（deleteMessage 按位置截断）
    final result = await AthenaDialog.confirm(
      'Delete this message and all messages after it?',
    );
    if (result == true) {
      await chatViewModel.deleteMessage(message);
    }
  }

  void openContextMenu(TapUpDetails details, MessageEntity message) {
    final contextMenu = DesktopMessageContextMenu(
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

  /// 轮次条 hover 到第 [absoluteIndex] 轮（整段会话下标）时取它的内容。
  /// 不在当前窗口里就返回 null，那一次预览直接跳过。
  ChatTurn? _turnAt(int absoluteIndex) {
    final index = absoluteIndex - _windowFirstTurnIndex;
    return index >= 0 && index < _windowTurns.length
        ? _windowTurns[index]
        : null;
  }

  /// 取轮次条子树：结构没变就复用上一次的实例。
  ///
  /// 复用是**必需的**，不是优化：宿主每次构建都由 `Watch` 触发（agent 工作
  /// 期间每帧一次），照常传一棵新子树会让它逐帧重建，而重建传导下去的脏标记
  /// 会绕过 `RepaintBoundary`——实测逐帧重绘（见 [_railKey] 的注释）。
  /// 结构真变了才新建，此时重建一次是该的。
  Widget _railFor({
    required int windowTurnCount,
    required int totalTurns,
    required int firstTurnIndex,
    required double barWidth,
  }) {
    final key = (
      windowTurnCount: windowTurnCount,
      totalTurns: totalTurns,
      firstTurnIndex: firstTurnIndex,
      barWidth: barWidth,
    );
    if (_rail != null && _railKey == key) return _rail!;
    _railKey = key;
    return _rail = RepaintBoundary(
      // 会话 id 进 key：两条会话的轮数恰好相同时结构 key 相等，光看结构 key
      // 会把上一条会话的 State（hover、预览卡、条的 GlobalKey）带过来
      key: ValueKey(_displayedChatId),
      child: TurnIndicator(
        windowTurnCount: windowTurnCount,
        turnAt: _turnAt,
        navigator: turnNavigator,
        maxBarWidth: barWidth,
        totalTurns: totalTurns,
        firstTurnIndex: firstTurnIndex,
        onTurnSelected: _selectTurn,
      ),
    );
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
    required AthenaTextSize textSize,
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
              AthenaWorkspaceTextSize(
                size: textSize,
                child: MessageCardListSliver(
                  messages: messages,
                  loading: loading,
                  sentinel: sentinel,
                  navigator: turnNavigator,
                  // 消息列与 composer 用同一条 768 定宽列并左缘对齐；
                  // 列内的左右留白由各消息自己带（助手 4 / 用户 12），
                  // 这里再加内边距会让正文右移 24。
                  padding: EdgeInsets.symmetric(
                    horizontal: columnPadding,
                    vertical: 12,
                  ),
                  onRewind: widget.onRewind,
                  onSecondaryTapUp: openContextMenu,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
