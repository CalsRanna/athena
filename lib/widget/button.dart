import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  const AIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hugeIcon = HugeIcon(icon: icon, color: const Color(0xff000000));
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: button,
    );
  }
}
