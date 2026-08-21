import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';

import 'package:flutter/material.dart';

class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    const textStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: colors.ctaGlow.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: colors.surfaceRaised,
      shadows: [boxShadow],
      shape: StadiumBorder(),
    );
    final button = Container(
      decoration: shapeDecoration,
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Center(child: Text('New Chat', style: textStyle)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => MobileChatRoute().push(context),
      child: button,
    );
  }
}
