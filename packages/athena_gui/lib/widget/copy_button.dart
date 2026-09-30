import 'dart:async';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 「已复制」反馈的状态机：点击进入已复制态，[AthenaMotion.linger] 后复原。
///
/// 只收敛三件容易写错的事——先复制再切状态、已复制期间重复点击不再复制、
/// 计时没走完就被卸载时不对已销毁的 State 调 setState；反馈长什么样交给
/// [builder] 画（同 [AthenaHover] 的分工：骨架共用，装饰各自画）。代码块的
/// 复制键是 [CopyButton]，消息工具条的复制键保留自己的外壳。
class CopyFeedback extends StatefulWidget {
  /// 点击时先复制，再切到已复制态。
  final void Function()? onTap;

  /// 用当前的已复制态构建子树。
  final Widget Function(BuildContext context, bool copied) builder;

  const CopyFeedback({super.key, this.onTap, required this.builder});

  @override
  State<CopyFeedback> createState() => _CopyFeedbackState();
}

class _CopyFeedbackState extends State<CopyFeedback> {
  bool copied = false;

  /// 计时结束前按钮可能被卸载（切换对话、流式重建），dispose 时取消，
  /// 不对已销毁的 State 调 setState。
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.builder(context, copied),
    );
  }

  void _handleTap() {
    // 已复制期间重复点击不再复制：剪贴板里已经是这份内容，再点一次只会把
    // 计时重新拉满，反馈一直挂在屏上。
    if (copied) return;
    widget.onTap?.call();
    setState(() => copied = true);
    _resetTimer = Timer(AthenaMotion.linger, () {
      setState(() => copied = false);
    });
  }
}

/// 「已复制」的内容：勾 + "Copied"。
///
/// 移动端只给勾：这是瞬时反馈，不该为一个马上要复原的提示把宽度撑出去
/// （代码块标题行、消息工具条都因此不动）。[iconSize] 与 [color] 由各自的
/// 容器决定——代码块语言条与自己的文案同号（`inlineSize`），消息工具条与
/// 自己的行内图标同档（`regularSize`）。文案固定走正文档：它出现在正文旁边，
/// 比正文小一号会显得是另一层的信息。
class CopiedLabel extends StatelessWidget {
  final Color color;
  final double iconSize;

  const CopiedLabel({
    super.key,
    required this.color,
    this.iconSize = AthenaIcon.inlineSize,
  });

  @override
  Widget build(BuildContext context) {
    var icon = Icon(LucideIcons.check, size: iconSize, color: color);
    if (!PlatformUtil.isDesktop) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text('Copied', style: AthenaTextStyle.body.copyWith(color: color)),
      ],
    );
  }
}

class CopyButton extends StatelessWidget {
  final void Function()? onTap;

  /// 图标与 "Copied" 的颜色。为空时按"浅底深字"取色（`textOnRaised` 在浅色
  /// 主题下是纯白，落在本组件当前的使用面——代码块语言条这类局部浅底上——
  /// 等于隐形，所以调用方要显式传该面上的正文色）。
  final Color? color;

  const CopyButton({super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final base = color ?? colors.textOnRaised;
    return CopyFeedback(
      onTap: onTap,
      builder: (context, copied) => AnimatedSwitcher(
        duration: AthenaMotion.hover,
        child: copied
            ? CopiedLabel(
                color: color ?? colors.textSecondaryOnRaised,
                iconSize: AthenaIcon.inlineSize,
              )
            : Icon(
                LucideIcons.copy,
                color: base.withValues(alpha: 0.4),
                size: AthenaIcon.inlineSize,
              ),
      ),
    );
  }
}
