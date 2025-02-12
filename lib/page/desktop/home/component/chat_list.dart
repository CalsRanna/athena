import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopChatListView extends ConsumerWidget {
  final void Function()? onDestroyed;
  final void Function(Chat)? onSelected;
  final Chat? selectedChat;
  const DesktopChatListView({
    super.key,
    this.onDestroyed,
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
    var textStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    if (chats.isEmpty) return Center(child: Text('No Chat', style: textStyle));
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
      onDestroyed: onDestroyed,
      onTap: () => selectChat(chat),
    );
  }

  void selectChat(Chat chat) {
    onSelected?.call(chat);
  }
}

class _ChatTile extends ConsumerStatefulWidget {
  final bool active;
  final Chat chat;
  final void Function()? onDestroyed;
  final void Function()? onTap;
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.onDestroyed,
    this.onTap,
  });

  @override
  ConsumerState<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends ConsumerState<_ChatTile> {
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
      onTap: () => handleTap(ref),
      onSecondaryTapUp: (details) => handleSecondaryTap(context, details),
      child: container,
    );
  }

  void handleSecondaryTap(BuildContext context, TapUpDetails details) {
    final position = details.globalPosition;
    var contextMenu = ContextMenu(chat: widget.chat, onTap: removeEntry);
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

  void handleTap(WidgetRef ref) {
    widget.onTap?.call();
  }

  void removeEntry() {
    entry?.remove();
    widget.onDestroyed?.call();
  }
}
