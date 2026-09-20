import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

class AthenaDivider extends StatelessWidget {
  final Color? color;
  final double? width;
  const AthenaDivider({super.key, this.color, this.width});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: color ?? colors.divider)),
      ),
      width: width,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: container,
    );
  }
}
