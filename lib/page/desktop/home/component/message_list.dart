import 'package:athena/component/message_list_tile.dart';
import 'package:athena/page/desktop/home/component/message_context_menu.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopMessageList extends ConsumerStatefulWidget {
  final Chat chat;
  final ScrollController? controller;
  final void Function(Message message) onResend;
  final Sentinel sentinel;
  const DesktopMessageList({
    super.key,
    required this.chat,
    this.controller,
    required this.onResend,
    required this.sentinel,
  });

  @override
  ConsumerState<DesktopMessageList> createState() => _DesktopMessageListState();
}

class _DesktopMessageListState extends ConsumerState<DesktopMessageList> {
  late final viewModel = ChatViewModel(ref);
  @override
  Widget build(BuildContext context) {
    var provider = messagesNotifierProvider(widget.chat.id);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  void copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  Future<void> destroyMessage(Message message) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this message?',
    );
    if (result == true) {
      viewModel.destroyMessage(message);
    }
  }

  void openContextMenu(TapUpDetails details, Message message) {
    var contextMenu = DesktopMessageContextMenu(
      offset: details.globalPosition,
      onCopied: () => copyMessage(message),
      onDestroyed: () => destroyMessage(message),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  Widget _buildData(List<Message> messages) {
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

  Widget _itemBuilder(List<Message> messages, int index) {
    final message = messages.reversed.elementAt(index);
    var loading = ref.watch(streamingNotifierProvider);
    if (index > 0) loading = false;
    return MessageListTile(
      loading: loading,
      message: message,
      onResend: () => widget.onResend.call(message),
      onSecondaryTapUp: (details) => openContextMenu(details, message),
      sentinel: widget.sentinel,
    );
  }
}
