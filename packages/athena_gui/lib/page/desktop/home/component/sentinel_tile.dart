import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopSentinelTile extends StatelessWidget {
  final void Function(SentinelEntity)? onChanged;
  const DesktopSentinelTile({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: HugeIcons.strokeRoundedLibrary,
      onTap: () => handleTap(context),
      title: 'Sentinel',
    );
  }

  Future<void> handleTap(BuildContext context) async {
    const route = DesktopSettingSentinelRoute();
    var sentinel = await route.push<SentinelEntity>(context);
    if (sentinel == null) return;
    onChanged?.call(sentinel);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final String title;
  const _Tile({required this.icon, this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var children = [
      Icon(icon, color: colors.textPrimary, size: 24),
      SizedBox(width: 12),
      Expanded(
        child: Text(title, style: TextStyle(color: colors.textPrimary)),
      ),
      SizedBox(width: 12),
      Icon(
        HugeIcons.strokeRoundedArrowRight01,
        color: colors.textPrimary,
        size: 16,
      ),
    ];
    var padding = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: padding,
    );
  }
}
