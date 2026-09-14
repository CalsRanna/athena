import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/util/compaction_step_formatter.dart';
import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/theme.dart';
import 'package:athena_tui/ui/widgets/message_card.dart';
import 'package:athena_tui/ui/widgets/streaming_progress_bar.dart';
import 'package:nocterm/nocterm.dart';

class CompactionCard extends StatefulComponent {
  const CompactionCard({super.key, required this.step, required this.isLive});
  final CompactionStep step;
  final bool isLive;

  @override
  State<CompactionCard> createState() => _CompactionCardState();
}

class _CompactionCardState extends State<CompactionCard> {
  bool _expanded = false;

  @override
  void didUpdateComponent(CompactionCard oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.step.compactionId != component.step.compactionId ||
        (!oldComponent.step.isTerminal && component.step.isTerminal)) {
      _expanded = false;
    }
  }

  @override
  Component build(BuildContext context) {
    final step = component.step;
    final running = component.isLive && !step.isTerminal;
    final color = switch (step.phase) {
      CompactionPhase.completed => AthenaCardColors.toolResult,
      CompactionPhase.failed => AthenaCardColors.error,
      CompactionPhase.cancelled => AthenaCardColors.cancelled,
      _ => running ? AthenaCardColors.toolCall : AthenaCardColors.cancelled,
    };
    return MessageCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              '${_expanded ? '▾' : '▸'} 上下文压缩 · ${compactionStatus(step, isLive: component.isLive)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              softWrap: true,
            ),
          ),
          Text(
            compactionTokenChange(step),
            style: AthenaTextStyles.dim,
            softWrap: true,
          ),
          if (running) const StreamingProgressBar(width: 12, pulseWidth: 4),
          if (_expanded)
            Text(
              sanitizeAnsi(compactionDetails(step)),
              style: AthenaTextStyles.dim,
              softWrap: true,
            ),
        ],
      ),
    );
  }
}
