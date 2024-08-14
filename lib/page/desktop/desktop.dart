import 'package:athena/page/desktop/component/chat.dart';
import 'package:athena/page/desktop/component/workspace.dart';
import 'package:athena/page/desktop/sentinel/form.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

class Desktop extends StatelessWidget {
  const Desktop({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Row(children: [ChatList(), Expanded(child: WorkSpace())]),
          _Toolbar(),
        ],
      ),
    );
  }
}

class _Buttons extends StatefulWidget {
  const _Buttons();

  @override
  State<_Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<_Buttons> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: Row(
        children: [
          _CloseButton(hover: hover),
          const SizedBox(width: 8),
          _MinimumButton(hover: hover),
          const SizedBox(width: 8),
          _FullScreenButton(hover: hover),
        ],
      ),
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}

class _CloseButton extends StatelessWidget {
  final bool hover;

  const _CloseButton({this.hover = false});

  @override
  Widget build(BuildContext context) {
    final icon = HugeIcon(
      color: Theme.of(context).colorScheme.onSurface,
      icon: HugeIcons.strokeRoundedCancel01,
      size: 10.0,
    );
    const placeholder = SizedBox(height: 10, width: 10);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: hover ? icon : placeholder,
      ),
    );
  }

  void handleTap() {
    windowManager.close();
  }
}

class _Create extends StatelessWidget {
  const _Create();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
        onTap: () => handleTap(ref),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPencilEdit02,
          color: onSurface.withOpacity(0.2),
        ),
      );
    });
  }

  void handleTap(WidgetRef ref) {
    ref.invalidate(chatNotifierProvider);
  }
}

class _Fold extends StatelessWidget {
  const _Fold();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: HugeIcon(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        icon: HugeIcons.strokeRoundedSidebarLeft,
      ),
    );
  }
}

class _FullScreenButton extends StatefulWidget {
  final bool hover;

  const _FullScreenButton({this.hover = false});

  @override
  State<_FullScreenButton> createState() => _FullScreenButtonState();
}

class _FullScreenButtonState extends State<_FullScreenButton> {
  bool fullScreen = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface;
    final child = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedArrowExpand02,
      size: 10,
    );
    const placeholder = SizedBox(height: 10, width: 10);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: widget.hover ? child : placeholder,
      ),
    );
  }

  void handleTap() {
    windowManager.setFullScreen(!fullScreen);
    setState(() {
      fullScreen = !fullScreen;
    });
  }
}

class _MinimumButton extends StatelessWidget {
  final bool hover;

  const _MinimumButton({this.hover = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface;
    final icon = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedRemove01,
      size: 10,
    );
    const placeholder = SizedBox(height: 10, width: 10);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: hover ? icon : placeholder,
      ),
    );
  }

  void handleTap() {
    windowManager.minimize();
  }
}

class _SentinelSelector extends StatefulWidget {
  const _SentinelSelector();

  @override
  State<_SentinelSelector> createState() => _SentinelSelectorState();
}

class _SentinelSelectorState extends State<_SentinelSelector> {
  OverlayEntry? entry;
  LayerLink link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: CompositedTransformTarget(
        link: link,
        child: Row(
          children: [
            Consumer(builder: (context, ref, child) {
              final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
              return Text(sentinel?.name ?? 'Athena');
            }),
            HugeIcon(
              color: onSurface.withOpacity(0.2),
              icon: HugeIcons.strokeRoundedArrowRight01,
            ),
          ],
        ),
      ),
    );
  }

  void handleTap() {
    entry = OverlayEntry(builder: (context) {
      return _Overlay(
        link: link,
        onTap: removeEntry,
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
  }
}

class _Overlay extends StatelessWidget {
  final LayerLink link;
  final void Function()? onTap;

  const _Overlay({required this.link, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Stack(
      children: [
        _Barrier(onTap: onTap),
        _Dialog(link: link, onTap: onTap),
      ],
    );
  }
}

class _Dialog extends StatelessWidget {
  final LayerLink link;
  final void Function()? onTap;

  const _Dialog({super.key, required this.link, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 12),
      targetAnchor: Alignment.bottomLeft,
      child: ACard(
        child: Consumer(builder: (context, ref, child) {
          final sentinels =
              ref.watch(sentinelsNotifierProvider).valueOrNull ?? [];
          final children = sentinels.map(
              (sentinel) => _SentinelTile(onTap: onTap, sentinel: sentinel));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...children,
              const _Divider(),
              _Tile(
                onTap: () => handleTap(context),
                title: 'Explore Sentinels',
              ),
            ],
          );
        }),
      ),
    );
  }

  void handleTap(BuildContext context) {
    onTap?.call();
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, _, __) {
        return const SentinelFormPage();
      },
    ));
  }
}

class _Divider extends StatelessWidget {
  const _Divider({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface.withOpacity(0.1);
    final border = Border(top: BorderSide(color: onSurface));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(border: border),
        width: 320,
      ),
    );
  }
}

class _Barrier extends StatelessWidget {
  const _Barrier({
    super.key,
    required this.onTap,
  });

  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox.expand(),
    );
  }
}

class _SentinelTile extends StatelessWidget {
  final void Function()? onTap;
  final Sentinel sentinel;

  const _SentinelTile({this.onTap, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    Widget? leading;
    if (sentinel.avatar.isNotEmpty) {
      leading = Text(
        sentinel.avatar,
        style: TextStyle(
          color: onSurface,
          decoration: TextDecoration.none,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return Consumer(builder: (context, ref, child) {
      return _Tile(
        leading: leading,
        onTap: () => handleTap(ref),
        title: sentinel.name,
      );
    });
  }

  void handleTap(WidgetRef ref) {
    onTap?.call();
    final notifier = ref.read(sentinelNotifierProvider.notifier);
    notifier.select(sentinel);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: handlePanStart,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const _Buttons(),
          // const SizedBox(width: 16),
          // const _FoldButton(),
          // const SizedBox(width: 200 - 16 * 2 - 14 * 3 - 8 * 2 - 48),
          const SizedBox(width: 200 - 16 - 14 * 3 - 8 * 2),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: onSurface.withOpacity(0.2)),
                ),
              ),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: const Row(
                children: [_SentinelSelector(), Spacer(), _Create()],
              ),
            ),
          )
        ],
      ),
    );
  }

  void handlePanStart(DragStartDetails details) {
    windowManager.startDragging();
  }
}

class _Tile extends StatefulWidget {
  final Widget? leading;
  final void Function()? onTap;
  final String title;

  const _Tile({super.key, this.leading, this.onTap, required this.title});

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceContainer = colorScheme.surfaceContainer;
    final onSurface = colorScheme.onSurface;
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
            color: hover ? surfaceContainer : Colors.transparent,
          ),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          width: 320,
          child: Row(
            children: [
              if (widget.leading != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: widget.leading,
                ),
              Text(
                widget.title,
                style: TextStyle(
                  color: onSurface,
                  decoration: TextDecoration.none,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}
