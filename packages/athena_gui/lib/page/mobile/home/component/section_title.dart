import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class SectionTitle extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  const SectionTitle(this.title, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(child: Text(title, style: textStyle)),
      _buildMoreButton(context),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceRaised,
      ),
      padding: EdgeInsets.all(12),
      child: Icon(HugeIcons.strokeRoundedArrowRight02, size: 16),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
