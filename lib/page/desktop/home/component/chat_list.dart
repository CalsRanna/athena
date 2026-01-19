import 'package:athena/entity/chat_entity.dart';
import 'package:athena/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopChatListView extends StatelessWidget {
  final void Function(ChatEntity)? onAutoRenamed;
  final void Function(List<ChatEntity>)? onBatchDestroyed;
  final void Function(ChatEntity)? onDestroyed;
  final void Function(ChatEntity)? onExportedImage;
  final void Function(ChatEntity)? onManualRenamed;
  final void Function(ChatEntity)? onPinned;
  final void Function(ChatEntity)? onSelected;

  const DesktopChatListView({
    super.key,
    this.onAutoRenamed,
    this.onBatchDestroyed,
    this.onDestroyed,
    this.onExportedImage,
    this.onManualRenamed,
    this.onPinned,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var chats = chatViewModel.chats.value;
      chatViewModel.initLastSelectedIndex();
      if (chats.isEmpty) return _buildEmpty();
      return ListView.separated(
        itemBuilder: (context, index) => _itemBuilder(context, chats, index),
        itemCount: chats.length,
        padding: EdgeInsets.all(12),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
    });
  }

  void _handleBatchDelete(
    BuildContext context,
    ChatViewModel viewModel,
    List<ChatEntity> chats,
  ) {
    var selectedChats = chats
        .where((c) => viewModel.selectedChatIds.value.contains(c.id))
        .toList();
    if (selectedChats.isNotEmpty) {
      onBatchDestroyed?.call(selectedChats);
      // clearSelection is called in batchDestroyChats after confirmation
    }
  }

  void _handleTap(ChatViewModel viewModel, ChatEntity chat, int index) {
    var isMetaPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    var isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isMetaPressed) {
      viewModel.toggleChatSelection(chat.id!, index);
    } else if (isShiftPressed &&
        (viewModel.lastSelectedIndex.value != null ||
            viewModel.selectedChatIds.value.isNotEmpty)) {
      viewModel.rangeSelectChats(index);
    } else {
      viewModel.clearSelection();
      viewModel.lastSelectedIndex.value = index;
      onSelected?.call(chat);
    }
  }

  void _openContextMenu(
    BuildContext context,
    TapUpDetails details,
    ChatEntity chat,
    List<ChatEntity> chats,
  ) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    if (chatViewModel.isMultiSelect.value) {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: details.globalPosition,
        multiSelect: true,
        selectedCount: chatViewModel.selectedChatIds.value.length,
        onDestroyed: () => _handleBatchDelete(context, chatViewModel, chats),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    } else {
      var contextMenu = DesktopChatContextMenu(
        chat: chat,
        offset: details.globalPosition,
        onAutoRenamed: () => onAutoRenamed?.call(chat),
        onDestroyed: () => onDestroyed?.call(chat),
        onExportedImage: () => onExportedImage?.call(chat),
        onManualRenamed: () => onManualRenamed?.call(chat),
        onPinned: () => onPinned?.call(chat),
      );
      DesktopContextMenuManager.instance.show(context, contextMenu);
    }
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

  Widget _itemBuilder(BuildContext context, List<ChatEntity> chats, int index) {
    var chat = chats[index];
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      var selectedChat = chatViewModel.currentChat.value;
      var selectedIds = chatViewModel.selectedChatIds.value;
      var renamingIds = chatViewModel.renamingChatIds.value;
      return _ChatTile(
        active: selectedChat?.id == chat.id,
        chat: chat,
        isRenaming: renamingIds.contains(chat.id),
        onTap: () => _handleTap(chatViewModel, chat, index),
        onSecondaryTap: (details) =>
            _openContextMenu(context, details, chat, chats),
        selected: selectedIds.contains(chat.id),
      );
    });
  }
}

class _ChatTile extends StatefulWidget {
  final bool active;
  final ChatEntity chat;
  final bool isRenaming;
  final void Function()? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  final bool selected;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.isRenaming = false,
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (widget.isRenaming) {
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ColorUtil.FFFFFFFF,
        ),
      );
    } else if (widget.chat.pinned) {
      trailing = Icon(
        HugeIcons.strokeRoundedPinLocation03,
        color: ColorUtil.FFFFFFFF,
        size: 16,
      );
    }
    return DesktopMenuTile(
      active: widget.active || widget.selected,
      label: widget.chat.title,
      trailing: trailing,
      onTap: widget.onTap,
      onSecondaryTap: widget.onSecondaryTap,
    );
  }
}
