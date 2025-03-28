import 'dart:io';

import 'package:athena/util/color_util.dart';
import 'package:athena/widget/window_button.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

class AthenaAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const AthenaAppBar({super.key, this.action, this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    if (isDesktop) {
      return _DesktopAppBar(action: action, leading: leading, title: title);
    }
    return _MobileAppBar(action: action, leading: leading, title: title);
  }
}

class DesktopPopButton extends StatelessWidget {
  const DesktopPopButton({super.key});

  @override
  Widget build(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
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
    const hugeIcon = Icon(
      HugeIcons.strokeRoundedArrowLeft02,
      color: ColorUtil.FF000000,
      size: 16,
    );
    const boxDecoration = BoxDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
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
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const _DesktopAppBar({this.action, this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    var leadingChildren = [
      MacWindowButton(),
      Expanded(child: leading ?? const SizedBox()),
      SizedBox(width: 16),
    ];
    var rowChildren = [
      SizedBox(width: 240, child: Row(children: leadingChildren)),
      Expanded(child: title ?? const SizedBox()),
      action ?? const SizedBox(),
      const SizedBox(width: 16),
    ];
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    var boxDecoration = BoxDecoration(border: Border(bottom: borderSide));
    var container = Container(
      decoration: boxDecoration,
      child: Row(children: rowChildren),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: handlePanStart,
      child: container,
    );
  }

  void handlePanStart(DragStartDetails details) {
    windowManager.startDragging();
  }
}

class _MobileAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? leading;
  final Widget? title;
  const _MobileAppBar({this.action, this.leading, this.title});

  @override
  Widget build(BuildContext context) {
    const defaultLeading = Align(
      alignment: Alignment.centerLeft,
      child: MobilePopButton(),
    );
    const textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
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
      Expanded(child: leading ?? defaultLeading),
      Expanded(flex: 2, child: center),
      Expanded(child: trailing),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: children),
    );
  }
}
