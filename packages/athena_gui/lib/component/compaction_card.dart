import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/util/compaction_step_formatter.dart';
import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single tool-style card whose identity survives every compaction phase.
class CompactionCard extends StatefulWidget {
  const CompactionCard({super.key, required this.step, required this.isLive});
  final CompactionStep step;
  final bool isLive;

  @override
  State<CompactionCard> createState() => _CompactionCardState();
}

class _CompactionCardState extends State<CompactionCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(CompactionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.compactionId != widget.step.compactionId ||
        (!oldWidget.step.isTerminal && widget.step.isTerminal)) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final step = widget.step;
    final running = widget.isLive && !step.isTerminal;
    final foreground = step.phase == CompactionPhase.failed
        ? colors.statusError
        : colors.textSecondaryOnRaised;
    final textStyle = GoogleFonts.firaCode(
      fontSize: 12,
      color: foreground,
      height: 1.6,
    );
    final status = compactionStatus(step, isLive: widget.isLive);
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: running,
              button: true,
              expanded: _expanded,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Expanded(
                      child: ToolHeaderShimmer(
                        active: running,
                        child: Row(
                          children: [
                            Icon(
                              step.phase == CompactionPhase.completed
                                  ? Icons.check_circle_outline
                                  : step.phase == CompactionPhase.failed
                                  ? Icons.error_outline
                                  : Icons.compress,
                              size: 15,
                              color: foreground,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('上下文压缩 · $status', style: textStyle),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: foreground,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(compactionTokenChange(step), style: textStyle),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 23),
                child: SelectableText(
                  compactionDetails(step),
                  style: textStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
