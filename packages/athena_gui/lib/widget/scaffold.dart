import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:flutter/material.dart';

/// 页面骨架。桌面端是"侧栏面板 + 画布工作区"，移动端是单列。
///
/// 壳层没有任何装饰性渐变：层次只靠暖灰画布、面板底色与 1px 接缝线
/// （见 [AthenaColors.borderChrome]）。
class AthenaScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const AthenaScaffold({super.key, this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    var isDesktop = PlatformUtil.isDesktop;
    if (isDesktop) return _DesktopScaffold(appBar: appBar, body: body);
    return _MobileScaffold(appBar: appBar, body: body);
  }
}

class _DesktopScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const _DesktopScaffold({this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var children = [
      appBar ?? const SizedBox(),
      Expanded(child: body ?? const SizedBox()),
    ];
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(children: children),
    );
  }
}

class _MobileScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const _MobileScaffold({this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    final children = [
      appBar ?? const SizedBox(),
      Expanded(child: body ?? const SizedBox()),
    ];
    final mediaQuery = MediaQuery.of(context);
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final container = Container(
      decoration: BoxDecoration(color: colors.surfaceMobile),
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Column(children: children),
    );
    return Scaffold(resizeToAvoidBottomInset: true, body: container);
  }
}
