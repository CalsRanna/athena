import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:flutter/material.dart';

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
    var innerDecoratedBox = DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Column(children: children),
    );
    var gradientColors = [
      colors.teal.withValues(alpha: 0.2),
      Colors.transparent,
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topRight,
      colors: gradientColors,
      end: Alignment.bottomLeft,
    );
    var outerDecoratedBox = DecoratedBox(
      decoration: BoxDecoration(gradient: linearGradient),
      child: innerDecoratedBox,
    );
    return Scaffold(body: outerDecoratedBox);
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
