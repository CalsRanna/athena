import 'package:athena/component/message_list_tile.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/desktop/home/component/message_context_menu.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageList extends StatefulWidget {
  final ChatEntity chat;
  final ScrollController? controller;
  final void Function(MessageEntity message) onResend;
  final SentinelEntity sentinel;
  const DesktopMessageList({
    super.key,
    required this.chat,
    this.controller,
    required this.onResend,
    required this.sentinel,
  });

  @override
  State<DesktopMessageList> createState() => _DesktopMessageListState();
}

class _DesktopMessageListState extends State<DesktopMessageList> {
  late final ChatViewModel chatViewModel;

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

  Widget _buildData(List<MessageEntity> messages) {
    if (messages.isEmpty == true) {
      return DesktopSentinelPlaceholder(sentinel: widget.sentinel);
    }
    return ListView.separated(
      controller: widget.controller,
      itemBuilder: (_, index) => _itemBuilder(messages, index),
      itemCount: messages.length,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(List<MessageEntity> messages, int index) {
    final message = messages.reversed.elementAt(index);
    return Watch((context) {
      var loading = chatViewModel.isStreaming.value;
      if (index > 0) loading = false;
      return MessageListTile(
        loading: loading,
        message: message,
        onResend: () => widget.onResend.call(message),
        onSecondaryTapUp: (details) => openContextMenu(details, message),
        sentinel: widget.sentinel,
      );
    });
  }
}
