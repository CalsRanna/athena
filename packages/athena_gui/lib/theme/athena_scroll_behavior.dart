import 'package:flutter/material.dart';

/// 全局滚动行为：桌面端不做 iOS 式回弹。
///
/// Flutter 给 macOS 默认装的是 `BouncingScrollPhysics`
/// （`ScrollBehavior.getScrollPhysics` 里的 `_bouncingDesktopPhysics`），
/// 于是鼠标滚轮 / 触控板滚到边界会先拉出一段空白再弹回去。那是触摸屏的
/// 惯性语义，放在桌面窗口里是持续的视觉噪音——列表每滚到底都晃一下。
/// 这里把桌面三平台统一换成 `ClampingScrollPhysics`（Windows / Linux 上
/// Flutter 的默认值本来就是它，换过来三端手感一致），移动端仍走
/// `super`，iOS 的回弹是系统预期。
///
/// 平台判定走 [getPlatform]（即 `ThemeData.platform`）而不是
/// `PlatformUtil`：Flutter 默认 physics 正是按这个信号分派的，两者必须同源，
/// 否则一旦显式指定 `ThemeData.platform` 就会出现「默认要弹、我们夹住」的
/// 错配；顺带也让 widget 测试能换平台断言。
///
/// 父级保留 [RangeMaintainingScrollPhysics]，与原默认一致：内容尺寸变化时
/// 维持滚动位置的那套校正是贴底跟随后续逻辑所依赖的。
class AthenaScrollBehavior extends MaterialScrollBehavior {
  const AthenaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return super.getScrollPhysics(context);
    }
  }
}
