import 'dart:io';

import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayUtil with TrayListener {
  static final SystemTrayUtil instance = SystemTrayUtil._();

  SystemTrayUtil._();

  /// 退出前的收尾回调（停止后台任务等）。在 exit(0) 之前 await，
  /// 否则进程先没了，子进程会变成孤儿。
  Future<void> Function()? onBeforeQuit;

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> ensureInitialized({Future<void> Function()? onBeforeQuit}) async {
    this.onBeforeQuit = onBeforeQuit;
    trayManager.addListener(this);
    await _setContextMenu();
    await _setTrayIcon();
  }

  @override
  void onTrayIconMouseDown() {
    WindowUtil.instance.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // bringAppToFront 使 Windows 在 TrackPopupMenu 前调用
    // SetForegroundWindow，否则托盘菜单点击外部无法关闭（Windows 经典行为）。
    // 该参数被 tray_manager 标记 deprecated（仅 Windows、未来移除）但无替代 API。
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'quit') {
      try {
        await onBeforeQuit?.call();
      } catch (e) {
        // 收尾失败不该挡退出：孤儿清理是下次启动的兜底。
        LoggerUtil.w('退出前收尾失败: $e');
      }
      exit(0);
    }
  }

  Future<void> _setContextMenu() async {
    final menu = Menu(
      items: [MenuItem(key: 'quit', label: '退出')],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> _setTrayIcon() async {
    try {
      String iconPath;
      bool isTemplate;
      if (Platform.isWindows) {
        iconPath = 'asset/image/tray_256x256.ico';
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
