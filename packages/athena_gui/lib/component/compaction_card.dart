import 'dart:convert';

import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/util/compaction_step_formatter.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:flutter/material.dart';

class CompactionCard extends StatelessWidget {
  const CompactionCard({super.key, required this.step, required this.isLive});

  final CompactionStep step;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final running = isLive && !step.isTerminal;
    final details = compactionDetails(step);
    return ToolCard(
      key: ValueKey(step.compactionId),
      toolName: '上下文压缩',
      arguments: jsonEncode({
        'call_description': compactionStatus(step, isLive: isLive),
      }),
      result: running
          ? null
          : step.phase == CompactionPhase.failed
          ? 'Error: $details'
          : details,
    );
  }
}
