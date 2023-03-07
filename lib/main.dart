import 'package:athena/creator/setting.dart';
import 'package:athena/router/router.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(CreatorGraph(child: const AthenaApp()));
}

class AthenaApp extends StatelessWidget {
  const AthenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return EmitterWatcher(
      emitter: settingEmitter,
      builder: (context, setting) => MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          brightness: setting.darkMode ? Brightness.dark : Brightness.light,
          colorSchemeSeed: Colors.greenAccent,
          useMaterial3: true,
        ),
      ),
    );
  }
}
