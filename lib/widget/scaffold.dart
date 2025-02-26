import 'dart:io';

import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';

class AthenaScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const AthenaScaffold({super.key, this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
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
    var children = [
      appBar ?? const SizedBox(),
      Expanded(child: body ?? const SizedBox()),
    ];
    var innerDecoratedBox = DecoratedBox(
      decoration: BoxDecoration(color: ColorUtil.FF282828),
      child: Column(children: children),
    );
    var colors = [
      ColorUtil.FF6ABEB9.withValues(alpha: 0.2),
      Colors.transparent
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topRight,
      colors: colors,
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
    final container = Container(
      decoration: const BoxDecoration(color: ColorUtil.FF282F32),
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Column(children: children),
    );
    return Scaffold(body: container);
  }
}
