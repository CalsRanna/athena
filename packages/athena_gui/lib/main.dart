import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/storage/legacy_storage_importer.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/util/single_instance_util.dart';
import 'package:athena_gui/util/system_tray_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 必须先于存储初始化：重复启动的进程在此直接退出，不会碰数据目录
  await SingleInstanceUtil.instance.ensureInitialized(args);
  final supportDir = await getApplicationSupportDirectory();
  DI.ensureInitialized(dataDirectory: supportDir.path);
  await _bootstrapStorage(supportDir);
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
    await SystemTrayUtil.instance.ensureInitialized();
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // 禁用 Signals 的 devtools 集成（桌面端无需信号调试面板，避免额外开销）
  SignalsObserver.instance = null;
  // 后台同步模型目录(models.dev),失败自动降级缓存,不阻塞启动
  unawaited(GetIt.instance<ModelCatalogService>().syncIfNeeded());
  runApp(const AthenaApp());
}

/// 文件存储启动序列:先读 provider(yaml)进内存,再把旧 SQLite 库
/// (若仍存在)按合并语义导入,最后种子内置角色。顺序不能变:导入按
/// 名字匹配 provider 依赖已加载的列表;种子必须在导入之后,否则会先
/// 占掉 id 1 再与旧库角色撞号。
Future<void> _bootstrapStorage(Directory supportDir) async {
  final storage = GetIt.instance<FileStorage>();
  await storage.load();
  await LegacyStorageImporter(
    storage: storage,
    dbFile: File(p.join(supportDir.path, 'athena.db')),
    // 桌面端旧版把工具输出写在 Application Support/.athena 下
    legacyToolOutputsDir: Directory(
      p.join(supportDir.path, '.athena', 'tool_outputs'),
    ),
  ).importIfNeeded();
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
      final textSize = settingViewModel.textSize.value;
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
        // 「字体大小」设置：叠一层 TextScaler（只缩放字号，不动几何）。
        builder: (context, child) => applyTextSize(context, child, textSize),
      );
    });
  }

  /// 把「字体大小」设置叠到系统文字缩放**之上**（不覆盖系统的无障碍缩放）。
  ///
  /// 默认档（1.0）直接返回原树，避免无谓地重建 MediaQuery。
  @visibleForTesting
  static Widget applyTextSize(
    BuildContext context,
    Widget? child,
    AthenaTextSize size,
  ) {
    var content = child ?? const SizedBox();
    if (size.scale == 1.0) return content;
    var media = MediaQuery.of(context);
    // 系统缩放是非线性的（Android 14+），所以按正文号取等效系数再相乘。
    var systemScale =
        media.textScaler.scale(AthenaFontSize.body) / AthenaFontSize.body;
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(systemScale * size.scale),
      ),
      child: content,
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
