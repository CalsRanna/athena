import 'dart:io';

import 'package:athena/database/database.dart';
import 'package:athena/di.dart';
import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/util/system_tray_util.dart';
import 'package:athena/util/window_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Database.instance.ensureInitialized();
  await WindowUtil.instance.ensureInitialized();
  await SystemTrayUtil.instance.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  SignalsObserver.instance = null;
  DI.ensureInitialized();
  runApp(const AthenaApp());
}

class AthenaApp extends StatefulWidget {
  const AthenaApp({super.key});

  @override
  State<AthenaApp> createState() {
    return _AthenaAppState();
  }
}

class _AthenaAppState extends State<AthenaApp> with WindowListener {
  final viewModel = GetIt.instance<SettingViewModel>();

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
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: themeData,
    );
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyW &&
        HardwareKeyboard.instance.isMetaPressed) {
      WindowUtil.instance.hide();
      return true;
    }
    return false;
  }

  @override
  void onWindowMoved() {
    viewModel.updateWindowSize();
    super.onWindowMoved();
  }

  @override
  void onWindowResized() {
    viewModel.updateWindowSize();
    super.onWindowResized();
  }
}
