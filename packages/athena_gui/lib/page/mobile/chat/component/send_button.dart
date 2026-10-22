import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

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
      final colors = context.athenaColors;
      final streaming = isStreaming;
      final enabled = streaming ? onTerminated != null : onSubmitted != null;
      final shapeDecoration = BoxDecoration(
        color: enabled ? colors.accent : colors.surfaceButtonSecondary,
        borderRadius: BorderRadius.circular(AthenaRadius.pill),
      );
      var iconData = LucideIcons.arrowUp;
      if (streaming) iconData = LucideIcons.square;
      final icon = Icon(
        iconData,
        color: enabled ? colors.textOnAccent : colors.textSecondary,
        size: AthenaIcon.regularSize,
      );
      final container = Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(8),
        child: icon,
      );
      final mobile = switch (context.athenaPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
      final visual = mobile
          ? SizedBox.square(
              dimension: AthenaIconButtonSize.touchTarget,
              child: Center(child: container),
            )
          : container;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(context, streaming),
        child: visual,
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
