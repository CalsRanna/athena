import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';

/// 按下缩放反馈：指针按下时把子树缩到 0.975，松开带弹簧回弹。
///
/// 触屏没有 hover，按下状态是唯一的即时反馈；缩放只改绘制、不改布局，
/// 命中区域与按下前一致。只用于**贴合内容尺寸**的可点控件（按钮、chip、
/// 图标键）。整行宽的可点区域不要用：0.975 落在几百像素宽的一行上就是十几
/// 像素的横向收缩，内容会明显离开容器边缘。
///
/// 用 [Listener] 采集原始指针事件而不是 `onTapDown`：它不参与手势竞技场，
/// 不会与子树的点击识别器抢手势。
class AthenaPressScale extends StatefulWidget {
  final Widget child;

  /// 为 false 时不缩放，用于不可点的控件。
  final bool enabled;

  const AthenaPressScale({super.key, required this.child, this.enabled = true});

  @override
  State<AthenaPressScale> createState() => _AthenaPressScaleState();
}

class _AthenaPressScaleState extends State<AthenaPressScale> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant AthenaPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 按住期间被禁用（例如点了就进入 loading）时已经收不到抬起事件；
    // 不在这里清掉，重新启用后会带着旧的按下态出现。
    if (_pressed && !widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 子树可能只是透明图标或留白：不设 opaque 的话命中测试落不到这里。
      // 尺寸仍由子树决定，不会扩大可点区域。
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        // 按下立刻跟手；回弹带弹簧，用标准档（DESIGN.md §6）。
        duration: _pressed ? AthenaMotion.fast : AthenaMotion.hover,
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }
}
