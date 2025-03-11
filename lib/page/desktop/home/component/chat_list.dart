import 'package:athena/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena/page/desktop/home/component/image_export.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatListView extends ConsumerWidget {
  final void Function(Chat)? onDestroyed;
  final void Function(Chat)? onRenamed;
  final void Function(Chat)? onSelected;
  final Chat? selectedChat;
  const DesktopChatListView({
    super.key,
    this.onDestroyed,
    this.onRenamed,
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
      onDestroyed: () => onDestroyed?.call(chat),
      onRenamed: () => onRenamed?.call(chat),
      onTap: () => selectChat(chat),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final bool active;
  final Chat chat;
  final void Function()? onDestroyed;
  final void Function()? onRenamed;
  final void Function()? onTap;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.onDestroyed,
    this.onRenamed,
    this.onTap,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    return DesktopMenuTile(
      active: widget.active,
      label: widget.chat.title,
      onTap: widget.onTap,
      onSecondaryTap: handleSecondaryTap,
    );
  }

  void handleDestroy() {
    entry?.remove();
    widget.onDestroyed?.call();
  }

  void renameChat() {
    entry?.remove();
    widget.onRenamed?.call();
  }

  Future<void> exportImage() async {
    entry?.remove();
    AthenaDialog.show(
      DesktopImageExportDialog(chat: widget.chat),
      barrierDismissible: true,
    );
  }

  void handleSecondaryTap(TapUpDetails details) {
    var contextMenu = DesktopChatContextMenu(
      offset: details.globalPosition,
      onBarrierTapped: removeEntry,
      onDestroyed: handleDestroy,
      onImageExported: exportImage,
      onRenamed: renameChat,
    );
    entry = OverlayEntry(builder: (context) => contextMenu);
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
  }
}
