import 'dart:async';

import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_scroll_behavior.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/util/single_instance_util.dart';
import 'package:athena_gui/util/system_tray_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 必须先于存储初始化：重复启动的进程在此直接退出，不会碰数据目录
  await SingleInstanceUtil.instance.ensureInitialized(args);
  final supportDir = await getApplicationSupportDirectory();
  DI.ensureInitialized(dataDirectory: supportDir.path);
  await _bootstrapStorage();
  await GetIt.instance<PermissionService>().load();
  await GetIt.instance<SettingViewModel>().initThemeMode();
  await GetIt.instance<SettingViewModel>().initTextSize();
  if (PlatformUtil.isDesktop) {
    // 窗口原生背景色跟随当前主题（浅色下避免露出默认黑底）
    final resolved = resolveColorMode(
      GetIt.instance<SettingViewModel>().themeMode.value,
    );
    final windowBg = colorsOf(resolved);
    await WindowUtil.instance.ensureInitialized(
      backgroundColor: windowBg.surface,
    );
    await SystemTrayUtil.instance.ensureInitialized(
      onBeforeQuit: () async {
        // 优雅退出：停止所有后台任务（强杀时走不到这里，由下次启动的
        // recoverOrphans 清理遗留进程）。
        await GetIt.instance<BackgroundTaskService>().stopAll();
      },
    );
    // 上次进程被强杀会留下后台任务子进程：启动时核对并清理。
    unawaited(GetIt.instance<BackgroundTaskService>().recoverOrphans());
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // 禁用 Signals 的 devtools 集成（桌面端无需信号调试面板，避免额外开销）
  SignalsObserver.instance = null;
  // 后台同步模型目录(models.dev),失败自动降级缓存,不阻塞启动
  unawaited(GetIt.instance<ModelCatalogService>().syncIfNeeded());
  runApp(const AthenaApp());
}

/// 文件存储启动序列:加载存储,再种子内置角色(首次启动)。
Future<void> _bootstrapStorage() async {
  final storage = GetIt.instance<FileStorage>();
  await storage.load();
  await const SentinelSeed().applyIfNeeded(
    sentinelRepo: storage.sentinelRepository,
  );
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
    return Watch((context) {
      final settingViewModel = GetIt.instance<SettingViewModel>();
      final themeMode = settingViewModel.themeMode.value;
      final resolved = resolveColorMode(themeMode);
      final colors = colorsOf(resolved);
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
        theme: buildAthenaThemeData(AthenaColorMode.light),
        darkTheme: buildAthenaThemeData(AthenaColorMode.dark),
        themeMode: themeMode,
        // 桌面端关闭滚动回弹（macOS 默认是 BouncingScrollPhysics）
        scrollBehavior: const AthenaScrollBehavior(),
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
