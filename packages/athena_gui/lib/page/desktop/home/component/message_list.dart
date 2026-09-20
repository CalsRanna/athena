import 'dart:async';

import 'package:athena_gui/component/chat_column.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/message_context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/elicit_card.dart';
import 'package:athena_gui/widget/permission_card.dart';
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

  late final ChatViewModel chatViewModel;
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  int? _displayedChatId;

  @override
  void initState() {
    super.initState();
    chatViewModel = GetIt.instance<ChatViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var messages = chatViewModel.messages.value;
      final loading = chatViewModel.isCurrentChatStreaming.value;
      final loadingHistory = chatViewModel.isLoadingMessages.value;
      return LayoutBuilder(
        builder: (context, constraints) => _buildData(
          messages,
          loading: loading,
          loadingHistory: loadingHistory,
          columnPadding: chatColumnPadding(constraints.maxWidth),
        ),
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

  SentinelEntity _displaySentinel() {
    if (chatViewModel.currentChat.value?.hasSentinel == false ||
        chatViewModel.currentSentinel.value?.id ==
            SentinelViewModel.directChatSentinel.id) {
      return SentinelViewModel.directChatSentinel;
    }
    return chatViewModel.currentSentinel.value ??
        sentinelViewModel.defaultSentinel.value;
  }

  Widget _buildData(
    List<MessageEntity> messages, {
    required bool loading,
    required bool loadingHistory,
    required double columnPadding,
  }) {
    var sentinel = _displaySentinel();
    widget.controller?.isWorking = loading;
    final chatId = chatViewModel.currentChat.value?.id;
    if (_displayedChatId != chatId) {
      _displayedChatId = chatId;
      widget.controller?.followBottom();
    } else {
      widget.controller?.maintainBottom();
    }
    // 当前对话挂起的权限审批卡片（非模态，随会话渲染）
    final approvals = chatViewModel.pendingApprovals.value
        .where((r) => r.chatId == chatViewModel.currentChat.value?.id)
        .toList();

    // 当前对话挂起的提问卡片（同一归属规则，排在审批卡片之后）
    final elicits = chatViewModel.pendingElicits.value
        .where((r) => r.chatId == chatViewModel.currentChat.value?.id)
        .toList();
    final content = messages.isEmpty
        ? DesktopSentinelPlaceholder(sentinel: sentinel)
        : NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: widget.controller?.handleMetricsNotification,
              child: CustomScrollView(
                controller: widget.controller,
                slivers: [
                  MessageCardListSliver(
                    messages: messages,
                    loading: loading,
                    sentinel: sentinel,
                    padding: EdgeInsets.symmetric(
                      horizontal: columnPadding + kChatColumnInnerPadding,
                      vertical: 12,
                    ),
                    onResend: widget.onResend,
                    onSecondaryTapUp: openContextMenu,
                  ),
                ],
              ),
            ),
          );
    final list = loadingHistory ? const SizedBox.expand() : content;
    // 返回结构必须与「有无审批」无关：根控件类型一旦随审批状态变化，滚动视图
    // 及其 ScrollPosition 会被整体重建，新 position 从偏移 0（列表顶部）
    // 起步，贴底校正要晚一帧才生效，表现为卡片弹出时列表先跳到顶部再跳回底部。
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(child: list),
          for (final request in approvals)
            Padding(
              padding: EdgeInsets.fromLTRB(
                columnPadding + kChatColumnInnerPadding,
                0,
                columnPadding + kChatColumnInnerPadding,
                12,
              ),
              child: PermissionApprovalCard(
                request: request,
                maxHeight:
                    constraints.maxHeight * permissionCardMaxHeightFraction,
                onDecision: (approved, persistExact) =>
                    chatViewModel.respondApproval(
                      request,
                      permissionDecisionOf(approved, persistExact),
                    ),
              ),
            ),
          for (final request in elicits)
            Padding(
              padding: EdgeInsets.fromLTRB(
                columnPadding + kChatColumnInnerPadding,
                0,
                columnPadding + kChatColumnInnerPadding,
                12,
              ),
              child: ElicitCard(
                request: request,
                maxHeight:
                    constraints.maxHeight * permissionCardMaxHeightFraction,
                onSubmit: (answers) =>
                    chatViewModel.respondElicit(request, answers),
              ),
            ),
        ],
      ),
    );
  }
}
