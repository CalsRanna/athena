import 'dart:io';

import 'package:athena/creator/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/router/router.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';

late Isar isar;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  isar = await Isar.open(
    [ChatSchema, ModelSchema, SettingSchema],
    directory: directory.path,
  );
  runApp(CreatorGraph(child: const AthenaApp()));
}

class AthenaApp extends StatefulWidget {
  const AthenaApp({super.key});

  @override
  State<AthenaApp> createState() {
    return _AthenaAppState();
  }
}

class _AthenaAppState extends State<AthenaApp> {
  final SystemTray tray = SystemTray();

  @override
  void initState() {
    super.initState();
    initTray();
  }

  @override
  Widget build(BuildContext context) {
    return EmitterWatcher(
      emitter: settingEmitter,
      builder: (context, setting) => MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          brightness: setting.darkMode ? Brightness.dark : Brightness.light,
          useMaterial3: true,
        ),
      ),
    );
  }

  initTray() async {
    if (Platform.isMacOS) {
      await tray.initSystemTray(iconPath: 'asset/image/icon.png');
    }
  }
}
