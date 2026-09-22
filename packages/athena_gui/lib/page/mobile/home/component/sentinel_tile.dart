import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';

import 'package:flutter/material.dart';

class SentinelTile extends StatelessWidget {
  final SentinelEntity sentinel;
  const SentinelTile(this.sentinel, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.label.copyWith(color: colors.textPrimary);
    final innerContainer = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(sentinel.name, style: textStyle),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateChatPage(context),
      child: innerContainer,
    );
  }

  void navigateChatPage(BuildContext context) {
    MobileChatRoute(sentinel: sentinel).push(context);
  }
}
