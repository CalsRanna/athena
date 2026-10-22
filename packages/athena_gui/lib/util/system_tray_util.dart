import 'dart:io';

import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayUtil {
  static final SystemTrayUtil instance = SystemTrayUtil._();

  SystemTrayUtil._();

  TrayIcon? _trayIcon;
  Menu? _menu;
  MenuItem? _quitItem;
  Image? _icon;

  /// 退出前的收尾回调（停止后台任务等）。在 exit(0) 之前 await，
  /// 否则进程先没了，子进程会变成孤儿。
  Future<void> Function()? onBeforeQuit;

  Future<void> dispose() async {
    // 先摘掉托盘图标再释放菜单与图像：图标仍引用它们时释放顺序反过来不安全。
    _trayIcon?.dispose();
    _trayIcon = null;
    _quitItem?.dispose();
    _quitItem = null;
    _menu?.dispose();
    _menu = null;
    _icon?.dispose();
    _icon = null;
  }

  Future<void> ensureInitialized({
    Future<void> Function()? onBeforeQuit,
  }) async {
    this.onBeforeQuit = onBeforeQuit;
    final trayIcon = TrayIcon.create();
    if (trayIcon == null) {
      LoggerUtil.w('无法创建托盘图标');
      return;
    }
    _trayIcon = trayIcon;
    trayIcon.addListener(_onTrayIconEvent);
    // 右键后由原生侧自动弹出菜单：Windows 会在弹出前把宿主窗口置前，
    // 点击菜单外部即可关闭，旧 API 的 popUpContextMenu 不再需要。
    trayIcon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    _setContextMenu(trayIcon);
    _setTrayIcon(trayIcon);
    trayIcon.setVisible(true);
  }

  void _onTrayIconEvent(TrayIconEvent event) {
    switch (event) {
      case TrayIconClickedEvent():
        WindowUtil.instance.show();
      case TrayIconRightClickedEvent():
      case TrayIconDoubleClickedEvent():
        break;
    }
  }

  Future<void> _quit() async {
    try {
      await onBeforeQuit?.call();
    } catch (e) {
      // 收尾失败不该挡退出：孤儿清理是下次启动的兜底。
      LoggerUtil.w('退出前收尾失败: $e');
    }
    exit(0);
  }

  void _setContextMenu(TrayIcon trayIcon) {
    final menu = Menu.create();
    if (menu == null) {
      LoggerUtil.w('无法创建托盘菜单');
      return;
    }
    final quit = MenuItem.createWithLabelAndType('退出', MenuItemType.normal);
    if (quit == null) {
      LoggerUtil.w('无法创建托盘菜单项');
      menu.dispose();
      return;
    }
    quit.addListener((event) async {
      if (event is MenuItemClickedEvent) await _quit();
    });
    menu.addItem(quit);
    trayIcon.setContextMenu(menu);
    _menu = menu;
    _quitItem = quit;
  }

  void _setTrayIcon(TrayIcon trayIcon) {
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

      final icon = ImageAsset.fromAsset(iconPath);
      if (icon == null) {
        LoggerUtil.w('无法加载托盘图标: $iconPath');
        return;
      }
      _icon = icon;
      // 图标尺寸沿用原生默认的 18×18（旧 API 的默认值）。
      trayIcon
        ..icon = icon
        ..isIconTemplate = isTemplate
        ..setTooltip('Athena');
    } catch (e, stackTrace) {
      LoggerUtil.e(e, stackTrace: stackTrace);
    }
  }
}
