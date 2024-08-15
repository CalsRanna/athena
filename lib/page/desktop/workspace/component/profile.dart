import 'package:athena/page/desktop/setting/setting.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/divider.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _Dialog extends StatelessWidget {
  final void Function()? onTap;
  const _Dialog({this.onTap});

  @override
  Widget build(BuildContext context) {
    return ACard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer(builder: (context, ref, child) {
            final setting = ref.watch(settingNotifierProvider).value;
            final key = setting?.key ?? '';
            String title = 'Set API Key First';
            if (key.isNotEmpty) {
              title = '${key.substring(0, 1)}***********************';
            }
            if (key.length > 24) {
              final leading = key.substring(0, 6);
              final tailing = key.substring(key.length - 6, key.length);
              title = '$leading************$tailing';
            }
            return ATile(title: title, width: 240);
          }),
          const ADivider(width: 240),
          ATile(title: 'Setting', onTap: () => handleTap(context), width: 240)
        ],
      ),
    );
  }

  void handleTap(BuildContext context) {
    onTap?.call();
    showDialog(context: context, builder: (context) => const Setting());
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
    setState(() {
      clicked = !clicked;
    });
    entry = OverlayEntry(builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: removeEntry,
        child: SizedBox.expand(
          child: UnconstrainedBox(
            child: CompositedTransformFollower(
              followerAnchor: Alignment.bottomLeft,
              link: link,
              offset: const Offset(24, 0),
              targetAnchor: Alignment.bottomRight,
              child: _Dialog(onTap: removeEntry),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
    setState(() {
      clicked = false;
    });
  }
}
