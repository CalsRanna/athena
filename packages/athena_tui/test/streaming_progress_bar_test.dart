import 'package:athena_tui/ui/widgets/streaming_progress_bar.dart';

import 'package:nocterm/nocterm_test.dart' as nocterm_test;
import 'package:test/test.dart';

void main() {
  group('StreamingProgressBar', () {
    test('渲染跑马灯进度条(亮块 + 暗块)', () {
      return nocterm_test.testNocterm('进度条渲染', (tester) async {
        await tester.pumpComponent(const StreamingProgressBar());
        // 推进动画:首帧 value=0 是全暗,亮块滑入后才有 '█'
        await tester.pump(const Duration(milliseconds: 300));

        final text = tester.terminalState.getText();
        expect(text, contains('█'));
        expect(text, contains('░'));
      });
    });

    test('动画推进时亮块位置变化', () {
      return nocterm_test.testNocterm('进度条动画', (tester) async {
        await tester.pumpComponent(const StreamingProgressBar(width: 20));
        await tester.pump(const Duration(milliseconds: 300));

        final before = tester.terminalState.getText();
        // 推进若干帧(动画 repeat 驱动)
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final after = tester.terminalState.getText();

        expect(before, isNot(equals(after)), reason: '亮块位置应随动画变化');
      });
    });

    test('总宽度等于配置的字符数', () {
      return nocterm_test.testNocterm('进度条宽度', (tester) async {
        await tester.pumpComponent(const StreamingProgressBar(width: 20, pulseWidth: 6));
        await tester.pump(const Duration(milliseconds: 300));

        final text = tester.terminalState.getText().trim();
        expect(text.length, 20, reason: '亮块+暗块总长应为配置宽度');
      });
    });
  });
}
