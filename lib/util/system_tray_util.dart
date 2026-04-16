import 'dart:io';

import 'package:athena/util/logger_util.dart';
import 'package:athena/util/window_util.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayUtil with TrayListener {
  static final SystemTrayUtil instance = SystemTrayUtil._();

  SystemTrayUtil._();

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> ensureInitialized() async {
    trayManager.addListener(this);
    await _setTrayIcon();
  }

  @override
  void onTrayIconMouseDown() {
    WindowUtil.instance.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    WindowUtil.instance.show();
  }

  Future<void> _setTrayIcon() async {
    try {
      String iconPath;
      bool isTemplate;
      if (Platform.isWindows) {
        iconPath = 'asset/image/tray_512x512.jpg';
        isTemplate = false;
      } else if (Platform.isMacOS) {
        iconPath = 'asset/image/tray_512x512.jpg';
        isTemplate = true;
      } else if (Platform.isLinux) {
        iconPath = 'asset/image/tray_512x512.jpg';
        isTemplate = false;
      } else {
        LoggerUtil.w('不支持的平台');
        return;
      }

      await trayManager.setIcon(iconPath, isTemplate: isTemplate);
      await trayManager.setToolTip('Athena');
    } catch (e, stackTrace) {
      LoggerUtil.e(e, stackTrace: stackTrace);
    }
  }
}
