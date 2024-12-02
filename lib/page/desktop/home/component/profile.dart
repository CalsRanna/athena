import 'package:athena/router/router.gr.dart';
import 'package:flutter/material.dart';

class ProfileTile extends StatefulWidget {
  const ProfileTile({super.key});

  @override
  State<ProfileTile> createState() => _ProfileTileState();
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      height: 28,
      width: 28,
      child: const Text('CA', style: TextStyle(fontSize: 12)),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Text('Cals Ranna', style: TextStyle(color: color));
  }
}

class _ProfileTileState extends State<ProfileTile> {
  bool clicked = false;
  OverlayEntry? entry;
  final link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryContainer = colorScheme.primaryContainer;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: CompositedTransformTarget(
        link: link,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: clicked ? primaryContainer : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Row(children: [
            _Avatar(),
            SizedBox(width: 8),
            Expanded(child: _Name())
          ]),
        ),
      ),
    );
  }

  void handleTap(BuildContext context) {
    // setState(() {
    //   clicked = !clicked;
    // });
    // entry = OverlayEntry(builder: (context) {
    //   return GestureDetector(
    //     behavior: HitTestBehavior.opaque,
    //     onTap: removeEntry,
    //     child: SizedBox.expand(
    //       child: UnconstrainedBox(
    //         child: CompositedTransformFollower(
    //           followerAnchor: Alignment.bottomLeft,
    //           link: link,
    //           offset: const Offset(24, 0),
    //           targetAnchor: Alignment.bottomRight,
    //           child: _Dialog(onTap: removeEntry),
    //         ),
    //       ),
    //     ),
    //   );
    // });
    // Overlay.of(context).insert(entry!);
    const DesktopSettingAccountRoute().push(context);
  }

  void removeEntry() {
    entry?.remove();
    setState(() {
      clicked = false;
    });
  }
}
