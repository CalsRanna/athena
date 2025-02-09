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
      DesktopContextMenuOption(text: 'Rename', onTap: onTap),
      DesktopContextMenuOption(text: 'Delete', onTap: () => destroy(ref)),
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

class DesktopContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onBarrierTapped;
  final double? width;
  final List<Widget> children;
  const DesktopContextMenu({
    super.key,
    required this.offset,
    this.onBarrierTapped,
    this.width,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildBarrier(),
      Positioned(left: offset.dx, top: offset.dy, child: _buildMenu(context)),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: onBarrierTapped,
      onTap: onBarrierTapped,
      child: Stack(children: children),
    );
  }

  Widget _buildBarrier() => const SizedBox.expand();

  Widget _buildMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final shadow = colorScheme.shadow.withValues(alpha: 0.1);
    final boxShadow = BoxShadow(color: shadow, blurRadius: 12, spreadRadius: 4);
    var boxDecoration = BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [boxShadow],
    );
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: width,
      child: Column(children: children),
    );
  }
}

class DesktopContextMenuOption extends StatefulWidget {
  final void Function()? onTap;
  final String text;

  const DesktopContextMenuOption({super.key, this.onTap, required this.text});

  @override
  State<DesktopContextMenuOption> createState() =>
      _DesktopContextMenuOptionState();
}

class DesktopMenuTile extends StatelessWidget {
  final bool active;
  final String label;
  final void Function()? onTap;
  final Widget? trailing;
  const DesktopMenuTile({
    super.key,
    required this.active,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);
    var textStyle = TextStyle(
      color: active ? Color(0xFF161616) : Colors.white,
      fontSize: 14,
      height: 1.5,
    );
    var animatedText = AnimatedDefaultTextStyle(
      duration: duration,
      style: textStyle,
      child: Text(label),
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(35),
      color: active ? Color(0xFFE0E0E0) : Color(0xFF616161),
    );
    var animatedContainer = AnimatedContainer(
      decoration: boxDecoration,
      duration: duration,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(child: animatedText),
          trailing ?? const SizedBox(),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: animatedContainer,
    );
  }
}

class _DesktopContextMenuOptionState extends State<DesktopContextMenuOption> {
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
