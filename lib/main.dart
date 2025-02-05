import 'dart:io';

import 'package:athena/provider/setting.dart';
import 'package:athena/router/router.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/util/proxy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

final globalKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarInitializer.ensureInitialized();
  final setting = await isar.settings.where().findFirst();
  ProxyConfig.instance.key = setting?.key ?? '';
  ProxyConfig.instance.url = setting?.url ?? '';
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();
    var size = Size(960, 720);
    if (setting != null) {
      var width = setting.width;
      var height = setting.height;
      if (width.isNaN) width = 960;
      if (height.isNaN) height = 720;
      size = Size(width, height);
    }
    final options = WindowOptions(
      center: true,
      minimumSize: const Size(960, 720),
      size: size,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }
  runApp(const ProviderScope(child: AthenaApp()));
}

class AthenaApp extends StatefulWidget {
  const AthenaApp({super.key});

  @override
  State<AthenaApp> createState() {
    return _AthenaAppState();
  }
}

class _AthenaAppState extends State<AthenaApp> with WindowListener {
  final SystemTray tray = SystemTray();
  final router = AppRouter(
    navigatorKey: globalKey,
  );

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final darkMode = setting?.darkMode ?? false;
      return MaterialApp.router(
        routerConfig: router.config(),
        theme: ThemeData(
          brightness: darkMode ? Brightness.dark : Brightness.light,
          fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
          useMaterial3: true,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    initTray();
    windowManager.addListener(this);
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

  @override
  void onWindowResized() {
    resizeWindow();
    super.onWindowResized();
  }

  Future<void> resizeWindow() async {
    final size = await windowManager.getSize();
    final setting = await isar.settings.where().findFirst();
    if (setting == null) return;
    setting.width = size.width;
    setting.height = size.height;
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }
}
