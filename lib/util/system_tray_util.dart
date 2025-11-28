import 'dart:io';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayUtil {
  static Future<void> ensureInitialized() async {
    final tray = SystemTray();
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
}
