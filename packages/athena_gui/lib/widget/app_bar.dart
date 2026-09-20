import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/widget/window_button.dart';
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
    var isDesktop = PlatformUtil.isDesktop;
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: colors.textPrimary,
      size: 18,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final hugeIcon = Icon(
      HugeIcons.strokeRoundedArrowLeft02,
      color: colors.iconOnRaised,
      size: 16,
    );
    final boxDecoration = BoxDecoration(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(AthenaRadius.control),
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 顶栏底色与画布相同（相当于透明），只有侧栏上方那条与侧栏同色。
    var rowChildren = [
      Container(
        width: AthenaSpace.sidebar,
        decoration: BoxDecoration(
          color: colors.surfacePanel,
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: Row(children: leadingChildren),
      ),
      Expanded(child: title ?? const SizedBox()),
      action ?? const SizedBox(),
      const SizedBox(width: 16),
    ];
    // Claude 实测：顶栏高 **46 逻辑**（我原来是 38），底边是一条**极浅**的线
    // `#F7F7F7`（只比画布暗 5/255），且贯穿整条——它是顶栏唯一的轮廓。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: handlePanStart,
      child: Container(
        height: 46,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F7))),
        ),
        child: Row(children: rowChildren),
      ),
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
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
