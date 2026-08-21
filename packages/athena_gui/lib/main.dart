import 'dart:async';
import 'dart:ui';

import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/util/system_tray_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Database.instance.ensureInitialized();
  final supportDir = await getApplicationSupportDirectory();
  DI.ensureInitialized(dataDirectory: supportDir.path);
  await GetIt.instance<PermissionService>().load();
  await GetIt.instance<SettingViewModel>().initThemeMode();
  if (PlatformUtil.isDesktop) {
    // 窗口原生背景色跟随当前主题（浅色下避免露出默认黑底）
    final resolved = _resolvedColorMode(
      GetIt.instance<SettingViewModel>().themeMode.value,
    );
    final windowBg = resolved == AthenaColorMode.light
        ? AthenaColors.light
        : AthenaColors.dark;
    await WindowUtil.instance.ensureInitialized(
      backgroundColor: windowBg.surface,
    );
    await SystemTrayUtil.instance.ensureInitialized();
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // 禁用 Signals 的 devtools 集成（桌面端无需信号调试面板，避免额外开销）
  SignalsObserver.instance = null;
  // 后台同步模型目录(models.dev),失败自动降级缓存,不阻塞启动
  unawaited(GetIt.instance<ModelCatalogService>().syncIfNeeded());
  runApp(const AthenaApp());
}

/// 解析主题模式为具体色板（system 按平台亮度）。
AthenaColorMode _resolvedColorMode(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => AthenaColorMode.light,
    ThemeMode.dark => AthenaColorMode.dark,
    ThemeMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.light
          ? AthenaColorMode.light
          : AthenaColorMode.dark,
  };
}

class AthenaApp extends StatefulWidget {
  const AthenaApp({super.key});

  @override
  State<AthenaApp> createState() {
    return _AthenaAppState();
  }
}

class _AthenaAppState extends State<AthenaApp> with WindowListener {
  /// 构建指定色板模式下的 ThemeData：品牌语义色走 [AthenaColors]
  /// 扩展，Material 组件适配走 ColorScheme。
  ThemeData _buildThemeData(AthenaColorMode mode) {
    final isLight = mode == AthenaColorMode.light;
    final colors = isLight ? AthenaColors.light : AthenaColors.dark;
    var sliderThemeData = SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
    );
    return ThemeData(
      fontFamily: PlatformUtil.isWindows ? 'Microsoft YaHei UI' : null,
      colorScheme: isLight
          ? const ColorScheme.light(
              primary: Color(0xFF4FA8A3),
              surface: Color(0xFFF2F3F5),
              onSurface: Color(0xFF1C1C1C),
            )
          : const ColorScheme.dark(
              primary: Color(0xFF6ABEB9),
              surface: Color(0xFF282828),
              onSurface: Color(0xFFFFFFFF),
            ),
      scaffoldBackgroundColor: colors.surface,
      sliderTheme: sliderThemeData,
      extensions: [colors],
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final themeMode = GetIt.instance<SettingViewModel>().themeMode.value;
      final resolved = _resolvedColorMode(themeMode);
      final colors = resolved == AthenaColorMode.light
          ? AthenaColors.light
          : AthenaColors.dark;
      if (PlatformUtil.isDesktop) {
        // 窗口原生背景色跟随主题（浅色下避免露出默认黑底）
        unawaited(windowManager.setBackgroundColor(colors.surface));
      }
      // 状态栏图标颜色跟随主题（浅色背景需深色图标）
      SystemChrome.setSystemUIOverlayStyle(
        resolved == AthenaColorMode.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      );
      return MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router.config(),
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: _buildThemeData(AthenaColorMode.light),
        darkTheme: _buildThemeData(AthenaColorMode.dark),
        themeMode: themeMode,
      );
    });
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
