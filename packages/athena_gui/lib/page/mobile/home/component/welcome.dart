import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MobileHomeWelcome extends StatefulWidget {
  const MobileHomeWelcome({super.key});

  @override
  State<MobileHomeWelcome> createState() => _MobileHomeWelcomeState();
}

class _MobileHomeWelcomeState extends State<MobileHomeWelcome> {
  @override
  Widget build(BuildContext context) {
    final settingsButton = AthenaIconButton(
      icon: LucideIcons.settings,
      onTap: () => handleTap(context),
    );
    final padding = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _buildText(context),
          const SizedBox(width: AthenaSpace.sm),
          settingsButton,
          const SizedBox(width: AthenaSpace.sm),
          _buildAvatar(context),
        ],
      ),
    );
    // Rebuild when page becomes visible to update the time-based greeting.
    return VisibilityDetector(
      key: const Key('MobileHomeWelcome'),
      onVisibilityChanged: handleVisibilityChanged,
      child: padding,
    );
  }

  String getPeriod() {
    final now = DateTime.now();
    if (now.hour < 12) {
      return 'morning';
    } else if (now.hour < 18) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }

  void handleTap(BuildContext context) {
    const MobileSettingRoute().push<void>(context);
  }

  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0.5) {
      setState(() {});
    }
  }

  Widget _buildAvatar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final circleAvatar = Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.border),
      padding: const EdgeInsets.all(4),
      child: const CircleAvatar(
        backgroundImage: AssetImage('asset/image/avatar.png'),
        radius: 28,
      ),
    );
    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: circleAvatar,
    );
    return gestureDetector;
  }

  Widget _buildText(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final welcomeTextStyle = AthenaTextStyle.hero.copyWith(
      color: colors.textPrimary,
    );
    final textChildren = [
      TextSpan(text: 'Good ${getPeriod()}!', style: welcomeTextStyle),
    ];
    return Expanded(child: Text.rich(TextSpan(children: textChildren)));
  }
}
