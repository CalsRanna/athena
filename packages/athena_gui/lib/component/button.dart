import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class CopyButton extends StatefulWidget {
  final void Function()? onTap;
  const CopyButton({super.key, this.onTap});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final color = colors.textOnRaised.withValues(alpha: 0.4);
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
    final color = colors.textOnRaised.withValues(alpha: 0.4);
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
      const Text('Copied', style: TextStyle(fontSize: 12, height: 1)),
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
