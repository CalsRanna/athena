import 'package:athena/router/router.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(CreatorGraph(child: const AthenaApp()));
}

class AthenaApp extends StatelessWidget {
  const AthenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.greenAccent),
    );
  }
}
