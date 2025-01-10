import 'dart:io';

import 'package:athena/widget/window_button.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const AAppBar({super.key, this.action, this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (!isDesktop) return _MobileAppBar(action: action, title: title);
    return _DesktopAppBar(leading: leading, title: title);
  }
}

class DesktopPopButton extends StatelessWidget {
  const DesktopPopButton({super.key});

  @override
  Widget build(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedArrowTurnBackward,
      color: Colors.white,
      size: 24,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: icon,
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).pop();
  }
}

class MobilePopButton extends StatelessWidget {
  const MobilePopButton({super.key});

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

class _DesktopAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  const _DesktopAppBar({this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    var rowChildren = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: MacWindowButton(),
      ),
      leading ?? const SizedBox(),
      Expanded(child: title ?? const SizedBox()),
    ];
    return Row(children: rowChildren);
  }
}

class _MobileAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? title;
  const _MobileAppBar({this.action, this.title});

  @override
  Widget build(BuildContext context) {
    const leading = Align(
      alignment: Alignment.centerLeft,
      child: MobilePopButton(),
    );
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
