import 'dart:io';

import 'package:flutter/material.dart';

class AScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const AScaffold({super.key, this.appBar, this.body});

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
    return Scaffold(body: Column(children: children));
  }
}

class _MobileScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const _MobileScaffold({this.appBar, this.body});

  @override
  Widget build(BuildContext context) {
    const linearGradient = LinearGradient(
      begin: Alignment.topRight,
      colors: [Color(0xff333333), Color(0xff111111)],
      end: Alignment.bottomLeft,
    );
    final children = [
      appBar ?? const SizedBox(),
      Expanded(child: body ?? const SizedBox()),
    ];
    final mediaQuery = MediaQuery.of(context);
    final container = Container(
      decoration: const BoxDecoration(gradient: linearGradient),
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Column(children: children),
    );
    return Scaffold(body: container);
  }
}
