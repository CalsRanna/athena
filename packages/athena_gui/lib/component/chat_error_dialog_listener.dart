import 'dart:async';

import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/widgets.dart';

/// 把聊天失败显示给用户。
///
/// 呈现是页面的责任：ViewModel 只发事件（`ChatViewModel.errors`），弹什么、弹在
/// 哪里由这一层定。桌面首页与移动聊天页各自包一层。
///
/// 只认 [Stream] 而不是直接吃 ViewModel，是为了让呈现逻辑能被单独测：测试注入一个
/// [StreamController] 和假的 [show] 即可，不必拉起整张依赖图，也不必为了弹一个
/// 对话框而准备好 Router（`AthenaDialog` 内部取的是 router 的 navigatorKey）。
class ChatErrorDialogListener extends StatefulWidget {
  const ChatErrorDialogListener({
    super.key,
    required this.errors,
    required this.child,
    this.show = AthenaDialog.error,
  });

  final Stream<String> errors;
  final Widget child;

  /// 实际呈现方式。默认弹错误对话框；测试可换成记录器。
  final void Function(String message) show;

  @override
  State<ChatErrorDialogListener> createState() =>
      _ChatErrorDialogListenerState();
}

class _ChatErrorDialogListenerState extends State<ChatErrorDialogListener> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.errors.listen(_onError);
  }

  @override
  void didUpdateWidget(ChatErrorDialogListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 事件源换了要重新订阅，否则会继续听旧的那条
    if (!identical(oldWidget.errors, widget.errors)) {
      _subscription?.cancel();
      _subscription = widget.errors.listen(_onError);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onError(String message) {
    // 事件可能来自任意后台路径（run 收尾、后台汇报、列表重载），到达时页面未必
    // 还挂着；拆掉了就不再弹。
    if (!mounted) return;
    widget.show(message);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
