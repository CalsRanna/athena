import 'package:athena_core/util/platform_util.dart';
import 'package:athena_gui/util/window_util.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

/// Windows 单实例守卫。
///
/// macOS 由 LaunchServices 保证同一 bundle id 只存在一个实例，再次打开只会向
/// 已有实例投递 reopen 事件；Windows 没有等价机制，`CreateProcess` 每次都会
/// 无条件产生新进程，因此必须由应用自己拦截。
class SingleInstanceUtil {
  static final SingleInstanceUtil instance = SingleInstanceUtil._();

  /// 命名管道 / 互斥体标识，仅允许 a-z、0-9、`_` 与 `-`。
  static const _pipeName = 'athena';

  SingleInstanceUtil._();

  /// 必须在 main 中尽早调用——要早于 `Database.ensureInitialized()`，否则重复
  /// 启动的进程会先打开 SQLite 再退出，与已有实例产生锁竞争。
  ///
  /// 非首个实例把 [args] 经命名管道交给正在运行的实例后自行退出。
  Future<void> ensureInitialized(List<String> args) async {
    if (!PlatformUtil.isWindows) return;
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      _pipeName,
      // 两段式激活缺一不可，且顺序固定（包内部先回调、后置前）：
      // 1. show() 负责 setSkipTaskbar(false) + 显示窗口——窗口收进托盘时被摘出
      //    了任务栏，原生侧无从恢复；顺带复用了托盘单击的同一条激活路径。
      // 2. bringWindowToFront 用 AttachThreadInput 抢占前台——window_manager 的
      //    focus() 只是裸调 SetForegroundWindow，非前台进程调用会被 Windows
      //    静默忽略（只闪任务栏图标）。
      onSecondWindow: (_) => WindowUtil.instance.show(),
      bringWindowToFront: true,
    );
  }
}
