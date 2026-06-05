import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/mobile/home/component/sentinel_tile.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SentinelListView extends StatelessWidget {
  final SentinelViewModel sentinelViewModel;
  const SentinelListView({super.key, required this.sentinelViewModel});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinels = sentinelViewModel.sentinels.value;
      return _buildData(sentinels);
    });
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    List<Widget> children1 = [];
    List<Widget> children2 = [];
    List<Widget> children3 = [];
    for (var i = 0; i < sentinels.length; i++) {
      var tile = SentinelTile(sentinels[i]);
      if (i % 3 == 0) children1.add(tile);
      if (i % 3 == 1) children2.add(tile);
      if (i % 3 == 2) children3.add(tile);
    }
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(spacing: 12, children: children1),
        Row(spacing: 12, children: children2),
        Row(spacing: 12, children: children3),
      ],
    );
    return SizedBox(
      height: 120,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        child: column,
      ),
    );
  }
}
