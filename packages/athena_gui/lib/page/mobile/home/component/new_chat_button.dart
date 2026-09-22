import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';

import 'package:flutter/material.dart';

class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.section.copyWith(
      color: colors.textOnRaised,
      fontWeight: FontWeight.w600,
    );
    final button = Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      child: Center(child: Text('New Chat', style: textStyle)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => MobileChatRoute().push(context),
      child: button,
    );
  }
}
