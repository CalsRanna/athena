import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

class AAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const AAppBar({super.key, this.action, this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (!isDesktop) return _MobileAppBar(action: action, title: title);
    return _DesktopAppBar(action: action, leading: leading, title: title);
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

class _DesktopAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const _DesktopAppBar({this.action, this.leading, this.title});

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
          Container(
            color: colorScheme.surfaceContainer,
            height: 50,
            width: 200,
            child: const Row(children: [
              SizedBox(width: 16),
              _Buttons(),
              // const SizedBox(width: 16),
              // const _FoldButton(),
              // const SizedBox(width: 200 - 16 * 2 - 14 * 3 - 8 * 2 - 48),
              SizedBox(width: 200 - 16 - 14 * 3 - 8 * 2),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: onSurface.withOpacity(0.2)),
                ),
              ),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  leading ?? const SizedBox(),
                  title ?? const SizedBox(),
                  const Spacer(),
                  action ?? const SizedBox(),
                ],
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

class _MobileAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? title;
  const _MobileAppBar({this.action, this.title});

  @override
  Widget build(BuildContext context) {
    const leading = Align(alignment: Alignment.centerLeft, child: _PopButton());
    const textStyle = TextStyle(
      color: Color(0xffffffff),
      fontSize: 20,
      height: 1.2,
    );
    final wrappedTitle = DefaultTextStyle(
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: title ?? const SizedBox(),
    );
    final center = Align(alignment: Alignment.center, child: wrappedTitle);
    final trailing = Align(
      alignment: Alignment.centerRight,
      child: action ?? const SizedBox(),
    );
    final children = [
      const Expanded(child: leading),
      Expanded(flex: 2, child: center),
      Expanded(child: trailing),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: children),
    );
  }
}

class _PopButton extends StatelessWidget {
  const _PopButton();

  @override
  Widget build(BuildContext context) {
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedArrowLeft01,
      color: Color(0xff000000),
    );
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: button,
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).pop();
  }
}
