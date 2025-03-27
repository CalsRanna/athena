import 'dart:io';

import 'package:athena/router/router.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarInitializer.ensureInitialized();
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();
    var size = Size(1080, 720);
    final setting = await isar.settings.where().findFirst();
    if (setting != null) {
      var width = setting.width;
      var height = setting.height;
      if (width.isNaN) width = 1080;
      if (height.isNaN) height = 720;
      size = Size(width, height);
    }
    final options = WindowOptions(
      center: true,
      minimumSize: const Size(1080, 720),
      size: size,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ProviderScope(child: AthenaApp()));
}

final globalKey = GlobalKey<NavigatorState>();

class AthenaApp extends StatefulWidget {
  const AthenaApp({super.key});

  @override
  State<AthenaApp> createState() {
    return _AthenaAppState();
  }
}

class _AthenaAppState extends State<AthenaApp> with WindowListener {
  final SystemTray tray = SystemTray();
  final router = AppRouter(navigatorKey: globalKey);

  @override
  Widget build(BuildContext context) {
    var sliderThemeData = SliderThemeData(
      showValueIndicator: ShowValueIndicator.always,
    );
    var themeData = ThemeData(
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
      scaffoldBackgroundColor: ColorUtil.FF282828,
      sliderTheme: sliderThemeData,
      useMaterial3: true,
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(),
      theme: themeData,
    );
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

  Future<void> moveWindow() async {
    final size = await windowManager.getSize();
    final setting = await isar.settings.where().findFirst();
    if (setting == null) return;
    setting.width = size.width;
    setting.height = size.height;
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  @override
  void onWindowMoved() {
    moveWindow();
    super.onWindowMoved();
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
