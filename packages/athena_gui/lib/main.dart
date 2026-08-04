import 'dart:async';

import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/util/color_util.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/util/system_tray_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals/signals.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Database.instance.ensureInitialized();
  if (PlatformUtil.isDesktop) {
    await WindowUtil.instance.ensureInitialized();
    await SystemTrayUtil.instance.ensureInitialized();
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  SignalsObserver.instance = null;
  final supportDir = await getApplicationSupportDirectory();
  DI.ensureInitialized(dataDirectory: supportDir.path);
  await GetIt.instance<PermissionService>().load();
  // 后台同步模型目录(models.dev),失败自动降级缓存,不阻塞启动
  unawaited(GetIt.instance<ModelCatalogService>().syncIfNeeded());
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
  @override
  Widget build(BuildContext context) {
    var sliderThemeData = SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
    );
    var themeData = ThemeData(
      fontFamily: PlatformUtil.isWindows ? 'Microsoft YaHei UI' : null,
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
  void dispose() {
    if (PlatformUtil.isDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (PlatformUtil.isDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      windowManager.addListener(this);
    }
  }

  @override
  void onWindowResized() {
    WindowUtil.instance.saveWindowSize();
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
}
