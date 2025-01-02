import 'package:athena/provider/chat.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopLeftBar extends StatelessWidget {
  const DesktopLeftBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 300,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Search(),
          SizedBox(height: 12),
          Expanded(child: _List()),
          SizedBox(height: 12),
          _Sentinel(),
          _Shortcut(),
          _Setting(),
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
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(ref),
        onSecondaryTapUp: (details) => handleSecondaryTap(context, details),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            color: widget.active ? Color(0xFFE0E0E0) : Color(0xFF616161),
          ),
          padding: EdgeInsets.fromLTRB(6, 6, 40, 6),
          child: Row(
            children: [
              Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(31),
                  color: Color(0xFF242424),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.chat.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: widget.active ? Color(0xFF161616) : Colors.white,
                      fontSize: 14,
                      height: 1.7),
                ),
              ),
            ],
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

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final chat = ref.watch(chatNotifierProvider).value;
      final chats = ref.watch(chatsNotifierProvider).value;
      if (chats == null) return const SizedBox();
      return ListView.separated(
        itemBuilder: (context, index) {
          return _ChatTile(
            active: chats.reversed.elementAt(index).id == chat?.id,
            chat: chats.reversed.elementAt(index),
          );
        },
        itemCount: chats.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Search',
      hintStyle: TextStyle(color: Color(0xFFC2C2C2), fontSize: 14),
    );
    var textField = TextField(
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

class _Shortcut extends StatelessWidget {
  const _Shortcut();

  @override
  Widget build(BuildContext context) {
    return _Tile(icon: HugeIcons.strokeRoundedCommand, title: 'Shortcut');
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
