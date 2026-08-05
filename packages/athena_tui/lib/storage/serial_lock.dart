/// 通用串行锁:保证同一资源上的操作按提交顺序执行。
///
/// 模式:调用方持有一个"上一个操作"的 Future 引用,每次调用传入
/// 该引用与 setter(回调闭包中更新引用),返回的 Future 代表本操作。
/// 前一个操作失败(如 IO 异常)不影响后续操作排队。
Future<T> serialLock<T>(
  Future<void>? previous,
  Future<T> Function() action,
  void Function(Future<void>) setter,
) {
  final result = (previous ?? Future<void>.value()).then((_) => action());
  setter(result.then((_) {}, onError: (_) {}));
  return result;
}
