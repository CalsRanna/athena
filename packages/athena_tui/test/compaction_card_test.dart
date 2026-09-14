import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_tui/ui/widgets/compaction_card.dart';
import 'package:nocterm/nocterm.dart' as n;
import 'package:nocterm/nocterm_test.dart' as nt;
import 'package:test/test.dart';

CompactionStep _step(CompactionPhase phase) => CompactionStep(
  messageId: 8,
  chatId: 1,
  runId: 1,
  phase: phase,
  startedAt: DateTime(2026),
  beforeTokens: 80000,
  messageCount: 24,
  afterTokens: phase == CompactionPhase.completed ? 9000 : null,
  summary: phase == CompactionPhase.completed ? 'SUMMARY_DETAILS' : '',
  error: phase == CompactionPhase.failed ? 'SERVICE_UNAVAILABLE' : null,
);

void main() {
  test(
    'phases update the same card, stop animation and allow expansion',
    () => nt.testNocterm('compaction', (tester) async {
      for (final phase in [
        CompactionPhase.triggered,
        CompactionPhase.summarizing,
        CompactionPhase.persisting,
      ]) {
        await tester.pumpComponent(
          CompactionCard(
            key: const n.ValueKey('step'),
            step: _step(phase),
            isLive: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final text = tester.terminalState.getText();
        expect('上下文压缩'.allMatches(text), hasLength(1));
        expect(text, contains('░'));
      }
      await tester.pumpComponent(
        CompactionCard(
          key: const n.ValueKey('step'),
          step: _step(CompactionPhase.completed),
          isLive: true,
        ),
      );
      await tester.pump();
      var text = tester.terminalState.getText();
      expect(text, contains('压缩完成'));
      expect(text, contains('80000 → 9000'));
      expect(text, isNot(contains('░')));
      expect(text, isNot(contains('SUMMARY_DETAILS')));
      // MessageCard supplies one row of padding; header begins at (2, 1).
      await tester.tap(4, 1);
      await tester.pump();
      text = tester.terminalState.getText();
      expect(text, contains('SUMMARY_DETAILS'));
      expect(text, contains('覆盖 24 条消息'));
      expect('上下文压缩'.allMatches(text), hasLength(1));
    }, size: const n.Size(70, 20)),
  );

  for (final phase in [CompactionPhase.failed, CompactionPhase.cancelled]) {
    test(
      '$phase removes running animation',
      () => nt.testNocterm('terminal state', (tester) async {
        await tester.pumpComponent(
          CompactionCard(step: _step(phase), isLive: true),
        );
        await tester.pump();
        final text = tester.terminalState.getText();
        expect(
          text,
          contains(phase == CompactionPhase.failed ? '压缩失败' : '压缩已取消'),
        );
        expect(text, isNot(contains('░')));
        await tester.tap(4, 1);
        await tester.pump();
        if (phase == CompactionPhase.failed) {
          expect(
            tester.terminalState.getText(),
            contains('SERVICE_UNAVAILABLE'),
          );
        }
      }),
    );
  }

  test(
    'reopened unfinished step is interrupted and does not animate',
    () => nt.testNocterm('interrupted', (tester) async {
      await tester.pumpComponent(
        CompactionCard(step: _step(CompactionPhase.summarizing), isLive: false),
      );
      await tester.pump();
      expect(tester.terminalState.getText(), contains('压缩已中断'));
      expect(tester.terminalState.getText(), isNot(contains('░')));
    }),
  );
}
