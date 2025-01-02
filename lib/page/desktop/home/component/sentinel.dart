import 'package:athena/page/desktop/sentinel/form.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/divider.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SentinelSelector extends StatefulWidget {
  const SentinelSelector({super.key});

  @override
  State<SentinelSelector> createState() => _SentinelSelectorState();
}

class _SentinelTile extends StatelessWidget {
  final void Function()? onTap;
  final Sentinel sentinel;

  const _SentinelTile({this.onTap, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    Widget? leading;
    if (sentinel.avatar.isNotEmpty) {
      leading = Text(
        sentinel.avatar,
        style: TextStyle(
          color: onSurface,
          decoration: TextDecoration.none,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    Widget? trailing;
    if (sentinel.avatar.isNotEmpty) {
      trailing = GestureDetector(
        onTap: () => updateSentinel(context),
        child: HugeIcon(
          color: onSurface.withValues(alpha: 0.2),
          icon: HugeIcons.strokeRoundedSettings02,
          size: 14,
        ),
      );
    }
    return Consumer(builder: (context, ref, child) {
      return ATile(
        height: 48,
        leading: leading,
        onTap: () => handleTap(ref),
        title: sentinel.name,
        trailing: trailing,
      );
    });
  }

  void handleTap(WidgetRef ref) {
    onTap?.call();
    final notifier = ref.read(sentinelNotifierProvider.notifier);
    notifier.select(sentinel);
  }

  void updateSentinel(BuildContext context) {
    onTap?.call();
    showDialog(
      context: context,
      builder: (_) => SentinelFormPage(sentinel: sentinel),
    );
  }
}

class _Barrier extends StatelessWidget {
  final void Function()? onTap;

  const _Barrier({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox.expand(),
    );
  }
}

class _Dialog extends StatelessWidget {
  final LayerLink link;
  final void Function()? onTap;

  const _Dialog({required this.link, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 12),
      targetAnchor: Alignment.bottomLeft,
      child: ACard(
        width: 320,
        child: Consumer(builder: (context, ref, child) {
          final sentinels =
              ref.watch(sentinelsNotifierProvider).valueOrNull ?? [];
          final children = sentinels.map(
              (sentinel) => _SentinelTile(onTap: onTap, sentinel: sentinel));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...children,
              const ADivider(),
              ATile(
                height: 48,
                onTap: () => handleTap(context),
                title: 'Explore Sentinels',
              ),
            ],
          );
        }),
      ),
    );
  }

  void handleTap(BuildContext context) {
    onTap?.call();
    showDialog(context: context, builder: (_) => const SentinelFormPage());
  }
}

class _Overlay extends StatelessWidget {
  final LayerLink link;
  final void Function()? onTap;

  const _Overlay({required this.link, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [_Barrier(onTap: onTap), _Dialog(link: link, onTap: onTap)],
    );
  }
}

class _SentinelSelectorState extends State<SentinelSelector> {
  OverlayEntry? entry;
  LayerLink link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: CompositedTransformTarget(
        link: link,
        child: Row(
          children: [
            Consumer(builder: (context, ref, child) {
              final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
              return Text(
                sentinel?.name ?? 'Athena',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              );
            }),
            const SizedBox(width: 8),
            Consumer(builder: (context, ref, child) {
              final chat = ref.watch(chatNotifierProvider).valueOrNull;
              if (chat == null) return const SizedBox();
              return _Tag(chat.model);
            }),
          ],
        ),
      ),
    );
  }

  void handleTap() {
    entry = OverlayEntry(builder: (context) {
      return _Overlay(
        link: link,
        onTap: removeEntry,
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          colors: [
            Color(0xFFEAEAEA).withValues(alpha: 0.17),
            Colors.white.withValues(alpha: 0),
          ],
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          color: Color(0xFF161616),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
