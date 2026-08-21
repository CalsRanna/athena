import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';

class SentinelPlaceholder extends StatelessWidget {
  final SentinelEntity? sentinel;
  const SentinelPlaceholder({super.key, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final nameTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    final descriptionTextStyle = TextStyle(
      color: colors.border,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var text = Text(
      sentinel?.name ?? '',
      style: nameTextStyle,
      textAlign: TextAlign.center,
    );
    var children = [
      text,
      const SizedBox(height: 36),
      Text(sentinel?.description ?? '', style: descriptionTextStyle),
    ];
    var column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    return Padding(padding: const EdgeInsets.all(16.0), child: column);
  }
}
