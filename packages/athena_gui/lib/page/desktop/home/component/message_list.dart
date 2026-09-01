import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/message_context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/permission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageList extends StatefulWidget {
  final ScrollController? controller;
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
  late final ChatViewModel chatViewModel;
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();

  @override
  void initState() {
    super.initState();
    chatViewModel = GetIt.instance<ChatViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var messages = chatViewModel.messages.value;
      return _buildData(messages);
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

  SentinelEntity _displaySentinel() {
    if (chatViewModel.currentChat.value?.hasSentinel == false ||
        chatViewModel.currentSentinel.value?.id ==
            SentinelViewModel.directChatSentinel.id) {
      return SentinelViewModel.directChatSentinel;
    }
    return chatViewModel.currentSentinel.value ??
        sentinelViewModel.defaultSentinel.value;
  }

  Widget _buildData(List<MessageEntity> messages) {
    var sentinel = _displaySentinel();
    final displayCards = buildMessageDisplayCards(messages);
    // 当前对话挂起的权限审批卡片（非模态，随会话渲染）
    final approvals = chatViewModel.pendingApprovals.value
        .where((r) => r.chatId == chatViewModel.currentChat.value?.id)
        .toList();
    final list = messages.isEmpty
        ? DesktopSentinelPlaceholder(sentinel: sentinel)
        : ListView.separated(
            controller: widget.controller,
            itemBuilder: (_, index) => _itemBuilder(displayCards, index),
            itemCount: displayCards.length,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
          );
    if (approvals.isEmpty) return list;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(child: list),
          for (final request in approvals)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
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
        ],
      ),
    );
  }

  Widget _itemBuilder(List<List<MessageEntity>> cards, int index) {
    final cardMessages = cards.reversed.elementAt(index);
    final message = cardMessages.first;
    var sentinel = _displaySentinel();

    // 只有第一项需要监听 streaming 状态
    if (index == 0) {
      return Watch((context) {
        // 仅当前显示的对话流式时展示 loading 态
        var loading = chatViewModel.isCurrentChatStreaming.value;
        return MessageListTile(
          loading: loading,
          message: message,
          assistantMessages: message.role == 'assistant'
              ? cardMessages
              : const [],
          onResend: () => widget.onResend.call(message),
          onSecondaryTapUp: (details) => openContextMenu(details, message),
          sentinel: sentinel,
        );
      });
    }

    return MessageListTile(
      loading: false,
      message: message,
      assistantMessages: message.role == 'assistant' ? cardMessages : const [],
      onResend: () => widget.onResend.call(message),
      onSecondaryTapUp: (details) => openContextMenu(details, message),
      sentinel: sentinel,
    );
  }
}
