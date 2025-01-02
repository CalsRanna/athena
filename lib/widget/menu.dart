import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContextMenu extends ConsumerWidget {
  final Chat chat;
  final void Function()? onTap;

  const ContextMenu({super.key, required this.chat, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var children = [
      ContextMenuOption(text: 'Rename', onTap: onTap),
      ContextMenuOption(text: 'Delete', onTap: () => destroy(ref)),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return ACard(child: column);
  }

  void destroy(WidgetRef ref) {
    final notifier = ref.read(chatsNotifierProvider.notifier);
    notifier.destroy(chat.id);
    onTap?.call();
  }
}

class ContextMenuOption extends StatefulWidget {
  final void Function()? onTap;
  final String text;

  const ContextMenuOption({super.key, this.onTap, required this.text});

  @override
  State<ContextMenuOption> createState() => _ContextMenuOptionState();
}

class _ContextMenuOptionState extends State<ContextMenuOption> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final surfaceContainer = colorScheme.surfaceContainer;
    var textStyle = TextStyle(
      color: onSurface,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? surfaceContainer : null,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: 100,
      child: Text(widget.text, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
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
