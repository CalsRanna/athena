import 'dart:io';

import 'package:athena/creator/setting.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/router/router.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarInitializer.ensureInitialized();
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      center: true,
      minimumSize: Size(1146, 822),
      size: Size(1146, 822),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(
    ProviderScope(
      child: CreatorGraph(
        observer: const CreatorObserver(),
        child: const AthenaApp(),
      ),
    ),
  );
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
  void didChangeDependencies() {
    initSetting();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final darkMode = setting?.darkMode ?? false;
      return MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          brightness: darkMode ? Brightness.dark : Brightness.light,
          fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
          useMaterial3: true,
        ),
      );
    });
  }

  initTray() async {
    if (Platform.isMacOS) {
      await tray.initSystemTray(
        iconPath: 'asset/image/tray_512x512.jpg',
        isTemplate: true,
      );
      tray.registerSystemTrayEventHandler((eventName) {
        windowManager.show();
      });
    }
  }

  void initSetting() async {
    final ref = context.ref;
    var setting = await isar.settings.where().findFirst();
    setting ??= Setting();
    ref.set(darkModeCreator, setting.darkMode);
    isar.writeTxn(() async {
      await isar.settings.put(setting!);
    });
  }
}
