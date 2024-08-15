import 'package:athena/page/desktop/workspace/component/profile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatList extends StatelessWidget {
  const ChatList({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainer;
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: const Column(
        children: [
          SizedBox(height: 50),
          _Search(),
          SizedBox(height: 8),
          Expanded(child: _List()),
          SizedBox(height: 8),
          ProfileTile(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final bool active;
  final Chat chat;

  const _ChatTile({this.active = false, required this.chat});

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final primaryContainer = colorScheme.primaryContainer;
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(ref),
        onSecondaryTapUp: (details) => handleSecondaryTap(context, details),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.active ? primaryContainer : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.chat.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: onSurface, fontSize: 14),
          ),
        ),
      );
    });
  }

  void handleSecondaryTap(BuildContext context, TapUpDetails details) {
    final position = details.globalPosition;
    entry = OverlayEntry(builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: removeEntry,
        child: Stack(
          children: [
            const SizedBox.expand(),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: _ContextMenu(chat: widget.chat, onTap: removeEntry),
            ),
          ],
        ),
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void handleTap(WidgetRef ref) {
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.replace(widget.chat);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
  }
}

class _ContextMenu extends StatelessWidget {
  final Chat chat;
  final void Function()? onTap;

  const _ContextMenu({required this.chat, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ACard(
      child: Consumer(builder: (context, ref, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Option(text: 'Rename', onTap: onTap),
            _Option(text: 'Delete', onTap: () => destroy(ref)),
          ],
        );
      }),
    );
  }

  void destroy(WidgetRef ref) {
    final notifier = ref.read(chatsNotifierProvider.notifier);
    notifier.destroy(chat.id);
    onTap?.call();
  }
}

class _Group extends StatelessWidget {
  final String? group;
  const _Group({this.group});

  @override
  Widget build(BuildContext context) {
    if (group == null) return const SizedBox(height: 8);
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface.withOpacity(0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(group!, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final chat = ref.watch(chatNotifierProvider).value;
      final chats = ref.watch(chatsNotifierProvider).value;
      if (chats == null) return const SizedBox();
      List<String> groups = [];
      return ListView.separated(
        itemBuilder: (context, index) {
          if (index == 0) {
            final group = getGroup(chats.reversed.elementAt(index).updatedAt);
            groups.add(group);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Group(group: group),
                SizedBox(
                  width: double.infinity,
                  child: _ChatTile(
                    active: chats.reversed.elementAt(index).id == chat?.id,
                    chat: chats.reversed.elementAt(index),
                  ),
                )
              ],
            );
          }
          return _ChatTile(
            active: chats.reversed.elementAt(index).id == chat?.id,
            chat: chats.reversed.elementAt(index),
          );
        },
        itemCount: chats.length,
        separatorBuilder: (context, index) {
          final group = getGroup(chats.reversed.elementAt(index).updatedAt);
          if (groups.contains(group)) return const _Group();
          groups.add(group);
          return _Group(group: group);
        },
      );
    });
  }

  String getGroup(DateTime updatedAt) {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return switch (difference.inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${difference.inDays} days ago'
    };
  }
}

class _Option extends StatefulWidget {
  final void Function()? onTap;
  final String text;

  const _Option({this.onTap, required this.text});

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final surfaceContainer = colorScheme.surfaceContainer;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: handleEnter,
        onExit: handleExit,
        child: Container(
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hover ? surfaceContainer : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          width: 100,
          child: Text(
            widget.text,
            style: TextStyle(
              color: onSurface,
              decoration: TextDecoration.none,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  void handleEnter(PointerEnterEvent _) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent _) {
    setState(() {
      hover = false;
    });
  }
}

class _Search extends StatelessWidget {
  const _Search();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Container(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(
          color: onSurface.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          HugeIcon(
            color: onSurface.withOpacity(0.2),
            icon: HugeIcons.strokeRoundedSearch01,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              cursorColor: onSurface,
              decoration: InputDecoration.collapsed(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color: onSurface.withOpacity(0.2),
                  fontSize: 14,
                  height: 16 / 14,
                ),
              ),
              style: const TextStyle(fontSize: 14, height: 16 / 14),
            ),
          ),
        ],
      ),
    );
  }
}
