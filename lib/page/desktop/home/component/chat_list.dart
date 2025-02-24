import 'package:athena/page/desktop/home/component/chat_context_menu.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
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
    final active = selectedChat?.id == chat.id;
    return _ChatTile(
      active: active,
      chat: chat,
      onDestroyed: () => onDestroyed?.call(chat),
      onRenamed: () => onRenamed?.call(chat),
      onTap: () => selectChat(chat),
    );
  }

  void selectChat(Chat chat) {
    onSelected?.call(chat);
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
    var textStyle = TextStyle(
      color: widget.active ? Color(0xFF161616) : Colors.white,
      fontSize: 14,
      height: 1.5,
    );
    var text = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      overflow: TextOverflow.ellipsis,
      style: textStyle,
      child: Text(widget.chat.title),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(35),
      color: widget.active ? Color(0xFFE0E0E0) : Color(0xFF616161),
    );
    var container = AnimatedContainer(
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: text,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onSecondaryTapUp: (details) => handleSecondaryTap(context, details),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
  }

  void handleSecondaryTap(BuildContext context, TapUpDetails details) {
    final position = details.globalPosition;
    var contextMenu = DesktopChatContextMenu(
      onDestroyed: handleDestroy,
      onRenamed: handleRename,
    );
    var children = [
      const SizedBox.expand(),
      Positioned(left: position.dx, top: position.dy, child: contextMenu),
    ];
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: removeEntry,
      child: Stack(children: children),
    );
    entry = OverlayEntry(builder: (context) => gestureDetector);
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
  }

  void handleDestroy() {
    entry?.remove();
    widget.onDestroyed?.call();
  }

  void handleRename() {
    entry?.remove();
    widget.onRenamed?.call();
  }
}
