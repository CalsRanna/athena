import 'dart:async';
import 'dart:io';

import 'package:athena_core/storage/user_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowEvent { shown }

class WindowUtil {
  static final WindowUtil instance = WindowUtil._();

  /// 窗口尺寸的键名。这两个键只由本类读写（它们表达的是窗口本身的状态，
  /// 不是某个 ViewModel 的设置项），所以常量放在这里。
  static const _keyWindowHeight = 'window_height';
  static const _keyWindowWidth = 'window_width';

  /// 默认尺寸，同时也是最小尺寸；恢复旧配置时先钳住，避免设帧后再次缩放。
  static const _defaultSize = Size(1080, 720);

  /// 拖动窗口时 `resized` 逐帧触发，而落盘是「读-改-整文件写 + 跨进程锁」，
  /// 每帧写一次既慢又与另一进程争锁。攒到尾沿一次写。
  static const _saveDebounce = Duration(milliseconds: 500);

  final _controller = StreamController<WindowEvent>();

  Timer? _saveTimer;

  WindowUtil._();

  Stream<WindowEvent> get stream => _controller.stream;

  Future<void> destroy() async {
    await _controller.close();
    await windowManager.destroy();
  }

  /// [backgroundColor] 窗口原生背景色（需与当前主题背景一致，
  /// 浅色主题下避免露出默认黑底）。
  Future<void> ensureInitialized({
    required UserSettingsStore settings,
    Color? backgroundColor,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) return;
    final width =
        await settings.getDouble(_keyWindowWidth) ?? _defaultSize.width;
    final height =
        await settings.getDouble(_keyWindowHeight) ?? _defaultSize.height;
    await windowManager.ensureInitialized();

    final options = WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      center: true,
      minimumSize: _defaultSize,
      size: Size(
        width.isFinite && width >= _defaultSize.width
            ? width
            : _defaultSize.width,
        height.isFinite && height >= _defaultSize.height
            ? height
            : _defaultSize.height,
      ),
      windowButtonVisibility: false,
      backgroundColor: backgroundColor,
      title: 'Athena',
    );
    // 此 API 只配置原生窗口，不等待 Flutter 首帧。不要在回调里提前 show：
    // main 在配置完成后才 runApp，统一由 show 等待实际绘制后显示。
    await windowManager.waitUntilReadyToShow(options);
    await windowManager.setPreventClose(!Platform.isWindows);
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
    // main 用 deferFirstFrame 阻止初始化期间的空白帧；托盘 / 单实例激活
    // 也必须等同一帧，不能绕过首次显示的门槛。后续调用此 Future 已完成。
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
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

  /// 记下当前窗口尺寸，等拖动停下来再落盘（见 [_saveDebounce]）。
  ///
  /// 传入的 store 只在真正写入时用到；拖动期间只是重置计时器。
  void saveWindowSize(UserSettingsStore settings) {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => _writeWindowSize(settings));
  }

  Future<void> _writeWindowSize(UserSettingsStore settings) async {
    if (await windowManager.isMaximized()) return;
    final size = await windowManager.getSize();
    await settings.setDouble(_keyWindowHeight, size.height);
    await settings.setDouble(_keyWindowWidth, size.width);
  }

  /// 立即写入未落盘的尺寸（退出前调用；[saveWindowSize] 的防抖会被取消）。
  Future<void> flushWindowSize(UserSettingsStore settings) async {
    if (_saveTimer == null) return;
    _saveTimer!.cancel();
    _saveTimer = null;
    await _writeWindowSize(settings);
  }
}
