import 'package:athena/page/desktop/workspace/component/chat.dart';
import 'package:athena/page/desktop/workspace/component/sentinel.dart';
import 'package:athena/page/desktop/workspace/component/workspace.dart';
import 'package:athena/provider/chat.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWorkspace extends StatelessWidget {
  const DesktopWorkspace({super.key});

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
                children: [SentinelSelector(), Spacer(), _Create()],
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
