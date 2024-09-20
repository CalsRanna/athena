import 'package:flutter/material.dart';

class AScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget? body;
  const AScaffold({super.key, this.appBar, this.body});

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
