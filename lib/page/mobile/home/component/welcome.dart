import 'package:athena/page/mobile/setting/setting.dart';
import 'package:athena/util/color_util.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MobileHomeWelcome extends StatefulWidget {
  const MobileHomeWelcome({super.key});

  @override
  State<MobileHomeWelcome> createState() => _MobileHomeWelcomeState();
}

class _MobileHomeWelcomeState extends State<MobileHomeWelcome> {
  @override
  Widget build(BuildContext context) {
    var padding = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [_buildText(), _buildAvatar(context)]),
    );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return const SettingPage();
        },
      ),
    );
  }

  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0.5) {
      setState(() {});
    }
  }

  Widget _buildAvatar(BuildContext context) {
    var circleAvatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorUtil.FFFFFFFF.withValues(alpha: 0.5),
      ),
      padding: EdgeInsets.all(4),
      child: CircleAvatar(
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

  Widget _buildText() {
    const welcomeTextStyle = TextStyle(
      color: ColorUtil.FFA7BA88,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    const nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    var textChildren = [
      TextSpan(text: 'Good ${getPeriod()}, ', style: welcomeTextStyle),
      TextSpan(text: 'Cals', style: nameTextStyle),
    ];
    return Expanded(child: Text.rich(TextSpan(children: textChildren)));
  }
}
