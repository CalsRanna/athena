import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SendButton extends StatelessWidget {
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  final bool isStreaming;
  const SendButton({
    super.key,
    this.onSubmitted,
    this.onTerminated,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var shapeDecoration = BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(AthenaRadius.pill),
      );
      final streaming = isStreaming;
      var iconData = HugeIcons.strokeRoundedSent;
      if (streaming) iconData = HugeIcons.strokeRoundedStop;
      var icon = Icon(iconData, color: Colors.white, size: 16);
      var container = Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(8),
        child: icon,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(context, streaming),
        child: container,
      );
    });
  }

  void handleTap(BuildContext context, bool streaming) {
    if (!streaming) {
      onSubmitted?.call();
      return;
    }
    onTerminated?.call();
  }
}
