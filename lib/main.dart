import 'dart:io';

import 'package:athena/database/database.dart';
import 'package:athena/di.dart';
import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化新的 Database (Laconic)
  await Database.instance.ensureInitialized();

  // 初始化 DI
  DI.ensureInitialized();

  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();

    // 从新的 SettingViewModel 读取窗口配置
    final settingViewModel = GetIt.instance<SettingViewModel>();
    await settingViewModel.initSignals();

    var width = settingViewModel.windowWidth.value;
    var height = settingViewModel.windowHeight.value;
    if (width.isNaN || width == 0) width = 1080;
    if (height.isNaN || height == 0) height = 720;

    final options = WindowOptions(
      center: true,
      minimumSize: const Size(1080, 720),
      size: Size(width, height),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  SignalsObserver.instance = null;
  runApp(const AthenaApp());
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
  late final settingViewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    var sliderThemeData = SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
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

  Future<void> saveWindowSize() async {
    final size = await windowManager.getSize();
    await settingViewModel.updateWindowSize(size.width, size.height);
  }

  @override
  void onWindowMoved() {
    saveWindowSize();
    super.onWindowMoved();
  }

  @override
  void onWindowResized() {
    saveWindowSize();
    super.onWindowResized();
  }
}
