import 'dart:async';

import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/component/sentinel_placeholder.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/workspace_text_size.dart';
import 'package:athena_gui/component/elicit_card.dart';
import 'package:athena_gui/component/permission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MessageListView extends StatefulWidget {
  final Future<void> Function(MessageEntity) onRewind;
  final ChatEntity chat;
  final ChatViewModel viewModel;
  final SentinelViewModel sentinelViewModel;
  final ModelEntity? model;
  final MessageListScrollController controller;
  final void Function(ChatEntity)? onChatTitleChanged;
  const MessageListView({
    super.key,
    required this.chat,
    required this.onRewind,
    required this.viewModel,
    required this.sentinelViewModel,
    required this.controller,
    this.model,
    this.onChatTitleChanged,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  static const double _loadOlderThreshold = 120;

  ChatViewModel get viewModel => widget.viewModel;
  SentinelViewModel get sentinelViewModel => widget.sentinelViewModel;
  MessageListScrollController get controller => widget.controller;
  String? _displayedChatId;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification is! ScrollUpdateNotification ||
        (notification.scrollDelta ?? 0) >= 0 ||
        notification.metrics.extentBefore > _loadOlderThreshold ||
        !viewModel.hasOlderMessages) {
      return false;
    }

    unawaited(
      controller.preservePositionWhilePrepending(viewModel.loadOlderMessages),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final textSize = GetIt.instance<SettingViewModel>().textSize.value;
      final sentinel = widget.chat.hasSentinel
          ? sentinelViewModel.sentinels.value
                .where((s) => s.id == widget.chat.sentinelId)
                .firstOrNull
          : SentinelViewModel.directChatSentinel;
      if (sentinel == null) return const SizedBox();

      final messages = viewModel.messages.value
          .where((m) => m.chatId == widget.chat.id)
          .toList();
      final loading = viewModel.isCurrentChatStreaming.value;
      controller.isWorking = loading;
      if (_displayedChatId != widget.chat.id) {
        _displayedChatId = widget.chat.id;
        controller.followBottom();
      } else {
        controller.maintainBottom();
      }
      // 当前对话挂起的权限审批卡片（非模态，随会话渲染）
      final approvals = viewModel.pendingApprovals.value
          .where((r) => r.chatId == widget.chat.id)
          .toList();

      // 当前对话挂起的提问卡片（同一归属规则，排在审批卡片之后）
      final elicits = viewModel.pendingElicits.value
          .where((r) => r.chatId == widget.chat.id)
          .toList();

      final loadingHistory =
          viewModel.isLoadingMessages.value &&
          viewModel.currentChat.value?.id == widget.chat.id;

      final content = messages.isEmpty
          ? SentinelPlaceholder(sentinel: sentinel)
          : NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: controller.handleMetricsNotification,
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    AthenaWorkspaceTextSize(
                      size: textSize,
                      child: MessageCardListSliver(
                        messages: messages,
                        loading: loading,
                        sentinel: sentinel,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onLongPress: openBottomSheet,
                        onRewind: widget.onRewind,
                      ),
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
            // 消息列表自身无垂直 padding（区别于桌面端），这里补 12，
            // 使最后一条消息与权限卡片之间的间距与消息间/权限卡间一致
            const SizedBox(height: 12),
            for (final (index, request) in approvals.indexed)
              Padding(
                // 最后一张卡片无需底部间距：输入框区域自带 16 外边距
                // （chat.dart _buildInput），与无卡片时消息→输入框的间距一致
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  index == approvals.length - 1 && elicits.isEmpty ? 0 : 12,
                ),
                child: PermissionApprovalCard(
                  request: request,
                  maxHeight:
                      constraints.maxHeight * permissionCardMaxHeightFraction,
                  onDecision: (approved) => viewModel.respondApproval(
                    request,
                    permissionDecisionOf(approved),
                  ),
                ),
              ),
            for (final (index, request) in elicits.indexed)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  index == elicits.length - 1 ? 0 : 12,
                ),
                child: ElicitCard(
                  request: request,
                  maxHeight:
                      constraints.maxHeight * permissionCardMaxHeightFraction,
                  onSubmit: (answers) =>
                      viewModel.respondElicit(request, answers),
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> destroyMessage(MessageEntity message) async {
    AthenaDialog.dismiss();
    if (_blockWhileStreaming()) return;
    // 与桌面端一致先确认：删除会连带删掉这条之后的全部消息
    final confirmed = await AthenaDialog.confirm(
      'Delete this message and all messages after it?',
    );
    if (confirmed != true) return;
    controller.followBottom();
    await viewModel.deleteMessage(message);
  }

  void openBottomSheet(MessageEntity message) {
    HapticFeedback.heavyImpact();
    AthenaDialog.show(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AthenaBottomSheetTile(
                leading: const Icon(LucideIcons.history),
                title: 'Rewind',
                onTap: () {
                  AthenaDialog.dismiss();
                  unawaited(widget.onRewind(message));
                },
              ),
              AthenaBottomSheetTile(
                leading: const Icon(LucideIcons.trash2),
                title: 'Delete',
                onTap: () => destroyMessage(message),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 运行中不许删除：会删掉正在运行的 run 的消息，run 随后
  /// 的写入又把它们补回来（与桌面端同一拦截）。
  bool _blockWhileStreaming() {
    if (!viewModel.isStreamingChat(widget.chat.id!)) return false;
    AthenaDialog.info('Please wait for the current session to finish.');
    return true;
  }
}
