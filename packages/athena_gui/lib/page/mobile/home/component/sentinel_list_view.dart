import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/mobile/home/component/sentinel_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SentinelListView extends StatelessWidget {
  final SentinelViewModel sentinelViewModel;
  const SentinelListView({super.key, required this.sentinelViewModel});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final sentinels = sentinelViewModel.sentinels.value;
      return _buildData(context, sentinels);
    });
  }

  Widget _buildData(BuildContext context, List<SentinelEntity> sentinels) {
    if (sentinels.isEmpty) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No Sentinels yet',
          style: AthenaTextStyle.caption.copyWith(color: colors.textWeak),
        ),
      );
    }
    // 单行横向排列，高度由 chip 自身决定：固定 120 高在系统大字号下会把
    // 文字裁掉，三行分栏的阅读顺序也不如一行扫过去直观。
    final row = Row(
      spacing: 12,
      children: [for (final sentinel in sentinels) SentinelTile(sentinel)],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      child: row,
    );
  }
}
