import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobileSentinelSelectDialog extends ConsumerWidget {
  final void Function(Sentinel)? onTap;
  const MobileSentinelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sentinelsNotifierProvider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Sentinel> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    return ListView.builder(
      itemBuilder: (context, index) => _itemBuilder(sentinels[index]),
      itemCount: sentinels.length,
      shrinkWrap: true,
    );
  }

  Widget _itemBuilder(Sentinel sentinel) {
    return AthenaBottomSheetTile(
      onTap: () => onTap?.call(sentinel),
      title: sentinel.name,
    );
  }
}
