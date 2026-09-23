import 'package:athena_core/util/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 桌面首页的页级快捷键，目前只有"新建对话"一条。
///
/// 激活键按平台**只注册一个**：macOS 是 ⌘N，Windows / Linux 是 Ctrl+N。
/// macOS 上不能顺手也收 Ctrl+N——那是文本框里 emacs 式的"下移一行"
/// （见 Flutter 的 `DefaultTextEditingShortcuts` macOS 表），抢了会改输入行为。
///
/// **为什么挂在首页而不是 `main.dart` 的全局 `HardwareKeyboard` 处理器**（⌘W
/// 隐藏窗口在那里）：⌘W 是窗口级动作，设置页打开着也得能用；新建对话是首页
/// 动作，要求"在设置页时不生效"。设置页与所有 `showDialog` 对话框都是压在首页
/// 之上的**路由**：路由入栈时 Flutter 把焦点整个搬到新路由的 FocusScope，按键
/// 事件从焦点节点沿祖先向上冒泡，走不到首页这棵子树，所以"设置页不生效"是路由
/// 焦点语义的自然结果，不需要查路由名；关掉设置页焦点回到首页，快捷键随之恢复。
///
/// 自带一层 [FocusScope]：桌面端点一下画布会让输入框失焦，失焦后焦点回到
/// **最近的** FocusScope——没有这一层就回到路由的 scope（在本组件之上），此后
/// 快捷键就收不到了；有了这一层，焦点落回本组件内部，快捷键照常。`autofocus`
/// 让首页刚建出来、还没有任何控件持焦时这一层就持焦，快捷键一开始就可用。
class DesktopHomeShortcuts extends StatelessWidget {
  final VoidCallback onNewChat;
  final Widget child;

  const DesktopHomeShortcuts({
    super.key,
    required this.onNewChat,
    required this.child,
  });

  /// 新建对话的激活键（按平台只有一个）。按住不放不重复触发。
  static final SingleActivator newChatActivator = SingleActivator(
    LogicalKeyboardKey.keyN,
    meta: PlatformUtil.isMacOS,
    control: !PlatformUtil.isMacOS,
    includeRepeats: false,
  );

  /// 新建对话快捷键在界面上的显示文本（侧栏 New chat 行的 hover 提示用）。
  ///
  /// 与 [newChatActivator] 同源：提示写的是哪套修饰键，就必须是这台机器上
  /// 真正注册的那套，否则 Windows 上会提示一个按不出来的 ⌘N。
  static String get newChatLabel => PlatformUtil.isMacOS ? '⌘N' : 'Ctrl+N';

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {newChatActivator: onNewChat},
      child: FocusScope(autofocus: true, child: child),
    );
  }
}
