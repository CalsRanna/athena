import 'package:athena/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopChatListView extends ConsumerWidget {
  final void Function(Chat)? onAutoRenamed;
  final void Function(Chat)? onDestroyed;
  final void Function(Chat)? onExportedImage;
  final void Function(Chat)? onManualRenamed;
  final void Function(Chat)? onPinned;
  final void Function(Chat)? onSelected;
  final Chat? selectedChat;
  const DesktopChatListView({
    super.key,
    this.onAutoRenamed,
    this.onDestroyed,
    this.onExportedImage,
    this.onManualRenamed,
    this.onPinned,
    this.onSelected,
    this.selectedChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = chatsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
  }

  void selectChat(Chat chat) {
    onSelected?.call(chat);
  }

  Widget _buildData(WidgetRef ref, List<Chat> chats) {
    if (chats.isEmpty) return const SizedBox();
    return ListView.separated(
      itemBuilder: (context, index) => _itemBuilder(chats[index]),
      itemCount: chats.length,
      padding: EdgeInsets.all(12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(Chat chat) {
    return _ChatTile(
      active: selectedChat?.id == chat.id,
      chat: chat,
      onAutoRenamed: () => onAutoRenamed?.call(chat),
      onDestroyed: () => onDestroyed?.call(chat),
      onExportedImage: () => onExportedImage?.call(chat),
      onManualRenamed: () => onManualRenamed?.call(chat),
      onPinned: () => onPinned?.call(chat),
      onSelected: () => selectChat(chat),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final bool active;
  final Chat chat;
  final void Function()? onAutoRenamed;
  final void Function()? onDestroyed;
  final void Function()? onExportedImage;
  final void Function()? onManualRenamed;
  final void Function()? onPinned;
  final void Function()? onSelected;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.onAutoRenamed,
    this.onDestroyed,
    this.onExportedImage,
    this.onManualRenamed,
    this.onPinned,
    this.onSelected,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (widget.chat.pinned) {
      trailing = Icon(
        HugeIcons.strokeRoundedPinLocation03,
        color: ColorUtil.FFFFFFFF,
        size: 16,
      );
    }
    return DesktopMenuTile(
      active: widget.active,
      label: widget.chat.title,
      trailing: trailing,
      onTap: widget.onSelected,
      onSecondaryTap: openContextMenu,
    );
  }

  void openContextMenu(TapUpDetails details) {
    var contextMenu = DesktopChatContextMenu(
      chat: widget.chat,
      offset: details.globalPosition,
      onAutoRenamed: widget.onAutoRenamed,
      onDestroyed: widget.onDestroyed,
      onExportedImage: widget.onExportedImage,
      onManualRenamed: widget.onManualRenamed,
      onPinned: widget.onPinned,
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }
}
