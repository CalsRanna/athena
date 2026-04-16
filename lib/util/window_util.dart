import 'dart:async';
import 'dart:io';

import 'package:athena/util/shared_preference_util.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowEvent { shown }

class WindowUtil {
  static final WindowUtil instance = WindowUtil._();

  final _controller = StreamController<WindowEvent>();

  WindowUtil._();

  Stream<WindowEvent> get stream => _controller.stream;

  Future<void> destroy() async {
    await _controller.close();
    await windowManager.destroy();
  }

  Future<void> ensureInitialized() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    var instance = SharedPreferenceUtil.instance;
    var height = await instance.getWindowHeight();
    var width = await instance.getWindowWidth();
    await windowManager.ensureInitialized();

    TitleBarStyle? titleStyle = TitleBarStyle.hidden;
    if (Platform.isWindows) {
      titleStyle = TitleBarStyle.normal;
    }
    final options = WindowOptions(
      center: true,
      minimumSize: const Size(1080, 720),
      size: Size(width, height),
      titleBarStyle: titleStyle,
      windowButtonVisibility: false,
      title: 'Athena',
    );
    bool isPreventClose = true;
    if (Platform.isWindows) {
      isPreventClose = false;
    }
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(isPreventClose);
    });
  }

  Future<void> hide() async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
  }

  Future<bool> isMaximized() async {
    return await windowManager.isMaximized();
  }

  Future<void> maximize() async {
    await windowManager.maximize();
  }

  Future<void> minimize() async {
    await windowManager.minimize();
  }

  Future<void> restore() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
  }

  Future<void> show() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    // 确保 Flutter 根焦点被激活
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.requestFocus();
    });
    _controller.add(WindowEvent.shown);
  }

  Future<void> startDragging() async {
    await windowManager.startDragging();
  }

  Future<void> unmaximize() async {
    await windowManager.unmaximize();
  }
}
