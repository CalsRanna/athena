import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileSentinelSelectDialog extends StatelessWidget {
  final void Function(SentinelEntity)? onTap;
  final SentinelViewModel sentinelViewModel;
  const MobileSentinelSelectDialog({
    super.key,
    this.onTap,
    required this.sentinelViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinels = sentinelViewModel.sentinels.value;
      return _buildData(sentinels);
    });
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      children: [
        AthenaBottomSheetTile(
          onTap: () => onTap?.call(SentinelViewModel.directChatSentinel),
          title: SentinelViewModel.directChatOptionLabel,
        ),
        ...sentinels.map(_itemBuilder),
      ],
    );
  }

  Widget _itemBuilder(SentinelEntity sentinel) {
    return AthenaBottomSheetTile(
      onTap: () => onTap?.call(sentinel),
      title: sentinel.name,
    );
  }
}
