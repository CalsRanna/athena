import 'package:athena/component/message_list_tile.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/mobile/chat/component/edit_message_dialog.dart';
import 'package:athena/page/mobile/chat/component/sentinel_placeholder.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MessageListView extends StatefulWidget {
  final ChatEntity chat;
  final ChatViewModel viewModel;
  final SentinelViewModel sentinelViewModel;
  final ModelEntity? model;
  final void Function(ChatEntity)? onChatTitleChanged;
  const MessageListView({
    super.key,
    required this.chat,
    required this.viewModel,
    required this.sentinelViewModel,
    this.model,
    this.onChatTitleChanged,
  });

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  final controller = ScrollController();

  ChatViewModel get viewModel => widget.viewModel;
  SentinelViewModel get sentinelViewModel => widget.sentinelViewModel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    await viewModel.refreshMessages(widget.chat.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinel = sentinelViewModel.sentinels.value
          .where((s) => s.id == widget.chat.sentinelId)
          .firstOrNull;
      if (sentinel == null) return const SizedBox();

      var messages = viewModel.messages.value
          .where((m) => m.chatId == widget.chat.id)
          .toList();
      if (messages.isEmpty) return SentinelPlaceholder(sentinel: sentinel);

      var loading = viewModel.isStreaming.value;

      final reversedMessages = messages.reversed.toList();
      return ListView.separated(
        controller: controller,
        itemBuilder: (_, index) => _itemBuilder(
          reversedMessages[index],
          sentinel,
          loading && index == 0,
          key: ValueKey(reversedMessages[index].id),
        ),
        itemCount: messages.length,
        padding: EdgeInsets.symmetric(horizontal: 16),
        reverse: true,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
      );
    });
  }

  void destroyMessage(MessageEntity message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.deleteMessage(message);
    AthenaDialog.dismiss();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void editMessage(MessageEntity message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.deleteMessage(message);
  }

  void openBottomSheet(MessageEntity message) {
    HapticFeedback.heavyImpact();
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () => openEditDialog(message),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyMessage(message),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  void openEditDialog(MessageEntity message) {
    AthenaDialog.dismiss();
    var dialog = MobileEditMessageDialog(
      message: message,
      onSubmitted: editMessage,
    );
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (_) => dialog,
      isScrollControlled: true,
    );
  }

  Future<void> resendMessage(MessageEntity message) async {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    await viewModel.deleteMessage(message);
    await viewModel.sendMessage(message, chat: widget.chat);
  }

  Widget _itemBuilder(
    MessageEntity message,
    SentinelEntity sentinel,
    bool loading, {
    Key? key,
  }) {
    return MessageListTile(
      key: key,
      loading: loading,
      message: message,
      onLongPress: () => openBottomSheet(message),
      onResend: () => resendMessage(message),
      sentinel: sentinel,
    );
  }
}
