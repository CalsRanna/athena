import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/window_button.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AthenaAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? title;
  const AthenaAppBar({super.key, this.action, this.title});

  @override
  Widget build(BuildContext context) {
    final isDesktop = switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (isDesktop) {
      return _DesktopAppBar(action: action, title: title);
    }
    return _MobileAppBar(action: action, title: title);
  }
}

class MobilePopButton extends StatelessWidget {
  const MobilePopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AthenaIconButton(
      icon: AthenaIcons.back,
      onTap: () => handleTap(context),
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).pop();
  }
}

class _DesktopAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? title;
  const _DesktopAppBar({this.action, this.title});

  @override
  Widget build(BuildContext context) {
    var leadingChildren = [
      MacWindowButton(),
      const Spacer(),
      SizedBox(width: 16),
    ];
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 顶栏底色与画布相同（相当于透明），只有侧栏上方那条与侧栏同色。
    //
    // 这块左条必须**满高**（0..46）并且自带右边线：它是侧栏右边线在顶栏里的
    // 那一段。之前它由 `Row` 默认的 center 对齐决定高度（只到 38，上下各留
    // 3.5px），竖线在顶栏里到不了顶栏底边，看上去就像被顶栏底线切断。
    final sidebarStrip = Container(
      width: AthenaSpace.sidebar,
      decoration: BoxDecoration(
        color: colors.surfacePanel,
        border: Border(right: BorderSide(color: colors.borderChrome)),
      ),
      child: Row(children: leadingChildren),
    );
    // 顶栏高 46 逻辑像素，底边沿用色板的 neutralHairline。
    // 它是顶栏唯一的轮廓，只画在工作区上方：
    // 画满整宽的话会横穿侧栏那条竖线（并在交叉处留一个 1px 的缺口），
    // 而侧栏上方本该是侧栏面板本身的延伸，不该有横线。
    final workspaceStrip = Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.neutralHairline)),
        ),
        child: Row(
          children: [
            Expanded(child: title ?? const SizedBox()),
            action ?? const SizedBox(),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: handlePanStart,
      child: SizedBox(
        height: 46,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [sidebarStrip, workspaceStrip],
        ),
      ),
    );
  }

  void handlePanStart(DragStartDetails details) {
    windowManager.startDragging();
  }
}

class _MobileAppBar extends StatelessWidget {
  final Widget? action;
  final Widget? title;
  const _MobileAppBar({this.action, this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.title.copyWith(color: colors.textPrimary);
    final wrappedTitle = DefaultTextStyle(
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: title ?? const SizedBox(),
    );
    return Padding(
      // 触摸盒比可见按钮每边多 8；外侧留 8 后，可见按钮仍距页面边缘 16。
      padding: const EdgeInsets.all(AthenaSpace.sm),
      child: SizedBox(
        height: AthenaIconButtonSize.touchTarget,
        // 尾部可以有多个按钮，不能固定分配四分之一宽度。
        child: NavigationToolbar(
          leading: const MobilePopButton(),
          middle: wrappedTitle,
          trailing: action,
          centerMiddle: true,
          middleSpacing: AthenaSpace.sm,
        ),
      ),
    );
  }
}
