import 'package:athena/component/divider.dart';
import 'package:athena/page/desktop/component/setting.dart';
import 'package:athena/provider/setting.dart';
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
    final color = getColor(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      height: 32,
      width: 32,
      child: const Text('CA'),
    );
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }
}

class _Dialog extends StatelessWidget {
  final void Function()? onTap;
  const _Dialog({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            return _ListTile(enabled: false, title: title);
          }),
          ADivider(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              width: 200),
          _ListTile(title: 'Setting', onTap: () => handleTap(context)),
        ],
      ),
    );
  }

  void handleTap(BuildContext context) {
    onTap?.call();
    showDialog(context: context, builder: (context) => const Setting());
  }
}

class _ListTile extends StatelessWidget {
  final bool enabled;
  final void Function()? onTap;
  final String title;
  const _ListTile({this.enabled = true, this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: SizedBox(
        height: 24,
        width: 200,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            decoration: TextDecoration.none,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Color getColor(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    if (!enabled) return color.withOpacity(0.4);
    return color;
  }

  void handleTap() {
    if (!enabled) return;
    onTap?.call();
  }
}

class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Text('Cals Ranna', style: TextStyle(color: color));
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
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
    final onPrimary = colorScheme.onPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: CompositedTransformTarget(
        link: link,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: clicked ? onPrimary.withOpacity(0.2) : null,
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
