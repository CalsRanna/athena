import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class CopyButton extends StatefulWidget {
  final void Function()? onTap;

  /// 图标与 "Copied" 的颜色。为空时按"浅底深字"取色（代码块等局部浅底）；
  /// 助手消息卡面即页面底色，那里要显式传页面上可读的浅色。
  final Color? color;

  const CopyButton({super.key, this.onTap, this.color});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final base = widget.color ?? colors.textOnRaised;
    final color = base.withValues(alpha: 0.4);
    Widget child = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedCopy01,
      size: 12.0,
    );
    if (copied) child = _buildCopiedRow();
    var animatedSwitcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: animatedSwitcher,
    );
  }

  Widget _buildCopiedRow() {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final color = widget.color ?? colors.textSecondaryOnRaised;
    var hugeIcon = HugeIcon(
      color: color,
      icon: HugeIcons.strokeRoundedTick01,
      size: 12.0,
    );
    var isDesktop = PlatformUtil.isDesktop;
    if (!isDesktop) return hugeIcon;
    var children = [
      hugeIcon,
      const SizedBox(width: 4),
      Text(
        'Copied',
        style: AthenaTextStyle.caption.copyWith(height: 1, color: color),
      ),
    ];
    return Row(children: children);
  }

  void handleTap() async {
    if (copied) return;
    widget.onTap?.call();
    setState(() {
      copied = true;
    });
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      copied = false;
    });
  }
}
