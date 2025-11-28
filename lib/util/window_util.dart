import 'dart:io';
import 'dart:ui';

import 'package:athena/util/shared_preference_util.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static Future<void> ensureInitialized() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    var instance = SharedPreferenceUtil.instance;
    var height = await instance.getWindowHeight();
    var width = await instance.getWindowWidth();
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
}
