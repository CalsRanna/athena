import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

class MacWindowButton extends StatefulWidget {
  const MacWindowButton({super.key});

  @override
  State<MacWindowButton> createState() => _MacWindowButtonState();
}

class _MacWindowButtonState extends State<MacWindowButton> {
  bool fullScreen = false;
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var fullScreenButton = _FullScreenButton(
      fullScreen: fullScreen,
      hover: hover,
      onToggle: toggleFullScreen,
    );
    var children = [
      _CloseButton(hover: hover),
      const SizedBox(width: 8),
      _MinimumButton(hover: hover),
      const SizedBox(width: 8),
      fullScreenButton,
    ];
    return MouseRegion(
      onEnter: handleEnter,
      onExit: handleExit,
      child: Row(children: children),
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

  void toggleFullScreen() {
    setState(() {
      fullScreen = !fullScreen;
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
    const boxDecoration = BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(2),
      child: hover ? icon : placeholder,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: container,
    );
  }

  void handleTap() {
    windowManager.close();
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
    const boxDecoration = BoxDecoration(
      color: Colors.orange,
      shape: BoxShape.circle,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(2),
      child: hover ? icon : placeholder,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: container,
    );
  }

  void handleTap() {
    windowManager.minimize();
  }
}

class _FullScreenButton extends StatelessWidget {
  final bool fullScreen;
  final bool hover;
  final void Function()? onToggle;
  const _FullScreenButton({
    this.fullScreen = false,
    this.hover = false,
    this.onToggle,
  });

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
    const boxDecoration = BoxDecoration(
      color: Colors.green,
      shape: BoxShape.circle,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(2),
      child: hover ? child : placeholder,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: container,
    );
  }

  void handleTap() {
    windowManager.setFullScreen(!fullScreen);
    onToggle?.call();
  }
}
