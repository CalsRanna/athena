import 'package:athena/provider/chat.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopLeftBar extends StatelessWidget {
  const DesktopLeftBar({super.key});

  @override
  Widget build(BuildContext context) {
    const children = [
      _Search(),
      SizedBox(height: 12),
      Expanded(child: _ChatListView()),
      SizedBox(height: 12),
      _Sentinel(),
      _Shortcut(),
      _Setting(),
    ];
    const column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: column,
    );
  }
}

class _ChatListView extends ConsumerWidget {
  const _ChatListView();

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
      itemBuilder: (context, index) => _itemBuilder(ref, chats[index]),
      itemCount: chats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(WidgetRef ref, Chat chat) {
    final currentChat = ref.watch(chatNotifierProvider(0)).value;
    final active = currentChat?.id == chat.id;
    return _ChatTile(active: active, chat: chat);
  }
}

class _ChatTile extends ConsumerStatefulWidget {
  final bool active;
  final Chat chat;

  const _ChatTile({this.active = false, required this.chat});

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
      child: Text(widget.chat.title ?? ''),
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
    final notifier = ref.read(chatNotifierProvider(0).notifier);
    notifier.replace(widget.chat);
  }

  void removeEntry() {
    entry?.remove();
  }
}

class _Search extends StatelessWidget {
  const _Search();

  @override
  Widget build(BuildContext context) {
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Search',
      hintStyle: TextStyle(color: Color(0xFFC2C2C2), fontSize: 14),
    );
    var textField = TextField(
      cursorColor: Colors.white,
      decoration: inputDecoration,
      style: const TextStyle(fontSize: 14),
    );
    var hugeIcon = HugeIcon(
      color: Color(0xFFC2C2C2),
      icon: HugeIcons.strokeRoundedSearch01,
      size: 24,
    );
    var children = [
      hugeIcon,
      const SizedBox(width: 10),
      Expanded(child: textField),
    ];
    var boxDecoration = BoxDecoration(
      border: Border.all(color: Color(0xFF757575)),
      color: Color(0xFFADADAD).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(56),
    );
    return Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: children),
    );
  }
}

class _Sentinel extends StatelessWidget {
  const _Sentinel();

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: HugeIcons.strokeRoundedLibrary,
      onTap: () => handleTap(context),
      title: 'Sentinel',
    );
  }

  void handleTap(BuildContext context) {
    const DesktopSentinelGridRoute().push(context);
  }
}

class _Setting extends StatelessWidget {
  const _Setting();

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: HugeIcons.strokeRoundedSettings01,
      onTap: () => handleTap(context),
      title: 'Setting',
    );
  }

  void handleTap(BuildContext context) {
    const DesktopSettingAccountRoute().push(context);
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut();

  @override
  Widget build(BuildContext context) {
    return _Tile(icon: HugeIcons.strokeRoundedCommand, title: 'Shortcut');
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final String title;
  const _Tile({required this.icon, this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    var children = [
      Icon(icon, color: Colors.white, size: 24),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(color: Colors.white))),
      const SizedBox(width: 12),
      Icon(HugeIcons.strokeRoundedArrowRight01, color: Colors.white, size: 16),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(children: children),
      ),
    );
  }
}
