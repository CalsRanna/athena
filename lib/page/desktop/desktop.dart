import 'dart:math';

import 'package:athena/page/desktop/component/chat_list.dart';
import 'package:athena/page/desktop/component/workspace.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
          _FullscreenButton(hover: hover),
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
        child: hover ? const Icon(Icons.close, size: 10) : placeholder,
      ),
    );
  }

  void handleTap() {
    windowManager.close();
  }
}

class _FoldButton extends StatelessWidget {
  const _FoldButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Icon(
        Icons.space_dashboard_outlined,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}

class _FullscreenButton extends StatefulWidget {
  final bool hover;
  const _FullscreenButton({this.hover = false});

  @override
  State<_FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<_FullscreenButton> {
  bool fullscreen = false;

  @override
  Widget build(BuildContext context) {
    final icon = fullscreen ? Icons.unfold_less : Icons.unfold_more;
    const angle = pi * 3 / 4;
    final child = Transform.rotate(angle: angle, child: Icon(icon, size: 10));
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
    windowManager.setFullScreen(!fullscreen);
    setState(() {
      fullscreen = !fullscreen;
    });
  }
}

class _MinimumButton extends StatelessWidget {
  final bool hover;
  const _MinimumButton({this.hover = false});

  @override
  Widget build(BuildContext context) {
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
        child: hover ? const Icon(Icons.remove, size: 10) : placeholder,
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
    return Row(
      children: [
        const SizedBox(width: 16),
        const _Buttons(),
        const SizedBox(width: 16),
        const _FoldButton(),
        const SizedBox(width: 200 - 16 * 2 - 14 * 3 - 8 * 2 - 48),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                const Text('Athena'),
                Icon(
                  Icons.chevron_right,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                ),
                const Spacer(),
                Icon(
                  Icons.maps_ugc_outlined,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                )
              ],
            ),
          ),
        )
      ],
    );
  }
}
