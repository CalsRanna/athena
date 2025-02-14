import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopSentinelSelector extends StatelessWidget {
  final void Function(Sentinel)? onSelected;
  const DesktopSentinelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedArtificialIntelligence03,
      color: Color(0xFF616161),
      size: 24,
    );
    return GestureDetector(onTap: openDialog, child: hugeIcon);
  }

  void changeModel(Sentinel sentinel) {
    ADialog.dismiss();
    onSelected?.call(sentinel);
  }

  void openDialog() {
    ADialog.show(
      _SentinelSelectDialog(onTap: changeModel),
      barrierDismissible: true,
    );
  }
}

class _SentinelSelectDialog extends ConsumerWidget {
  final void Function(Sentinel)? onTap;
  const _SentinelSelectDialog({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sentinelsNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return UnconstrainedBox(child: ACard(child: child));
  }

  Widget _buildData(List<Sentinel> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    List<Widget> children = sentinels.map(_itemBuilder).toList();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(500, 600)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _itemBuilder(Sentinel sentinel) {
    return ATile(
      onTap: () => onTap?.call(sentinel),
      title: sentinel.name,
      width: 480,
    );
  }
}
