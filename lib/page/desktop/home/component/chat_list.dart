import 'package:athena/entity/chat_entity.dart';
import 'package:athena/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopChatListView extends StatelessWidget {
  final void Function(ChatEntity)? onAutoRenamed;
  final void Function(ChatEntity)? onDestroyed;
  final void Function(ChatEntity)? onExportedImage;
  final void Function(ChatEntity)? onManualRenamed;
  final void Function(ChatEntity)? onPinned;
  final void Function(ChatEntity)? onSelected;
  final ChatEntity? selectedChat;
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
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var chats = chatViewModel.chats.value;
      return _buildData(chats);
    });
  }

  void selectChat(ChatEntity chat) {
    onSelected?.call(chat);
  }

  Widget _buildData(List<ChatEntity> chats) {
    if (chats.isEmpty) return _buildEmpty();
    return ListView.separated(
      itemBuilder: (context, index) => _itemBuilder(chats[index]),
      itemCount: chats.length,
      padding: EdgeInsets.all(12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _buildEmpty() {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Center(child: Text('No Chats', style: textStyle));
  }

  Widget _itemBuilder(ChatEntity chat) {
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
  final ChatEntity chat;
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
