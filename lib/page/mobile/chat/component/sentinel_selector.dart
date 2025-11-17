import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileSentinelSelectDialog extends StatelessWidget {
  final void Function(SentinelEntity)? onTap;
  const MobileSentinelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinelViewModel = GetIt.instance<SentinelViewModel>();
      var sentinels = sentinelViewModel.sentinels.value;
      return _buildData(sentinels);
    });
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    return ListView.builder(
      itemBuilder: (context, index) => _itemBuilder(sentinels[index]),
      itemCount: sentinels.length,
      padding: EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
    );
  }

  Widget _itemBuilder(SentinelEntity sentinel) {
    return AthenaBottomSheetTile(
      onTap: () => onTap?.call(sentinel),
      title: sentinel.name,
    );
  }
}
