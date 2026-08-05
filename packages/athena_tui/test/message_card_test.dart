import 'package:athena_tui/ui/widgets/message_card.dart';
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/nocterm_test.dart' as nocterm_test;
import 'package:test/test.dart';

void main() {
  group('MessageCard', () {
    test('渲染左侧色块竖条(默认半宽)', () {
      return nocterm_test.testNocterm('竖条半宽', (tester) async {
        await tester.pumpComponent(
          MessageCard(
            color: nocterm.Color.fromRGB(106, 190, 185),
            child: const nocterm.Text('内容', softWrap: true),
          ),
        );
        await tester.pump();

        // (0,0) 应是半块字符 ▌,前景色 teal
        final cell = tester.terminalState.getCellAt(0, 0);
        expect(cell, isNotNull);
        expect(cell!.char, '▌', reason: '默认半宽应渲染 ▌ 半块字符');
        expect(cell.style.color?.red, 106);
        expect(cell.style.color?.green, 190);
        expect(cell.style.color?.blue, 185);
        expect(tester.terminalState.containsText('内容'), isTrue);
      });
    });

    test('barWidth 控制竖条宽度', () {
      return nocterm_test.testNocterm('竖条宽度', (tester) async {
        // 全宽 → █
        await tester.pumpComponent(
          MessageCard(
            color: nocterm.Color.fromRGB(106, 190, 185),
            borderWidth: 1.0,
            child: const nocterm.Text('内容', softWrap: true),
          ),
        );
        await tester.pump();
        expect(tester.terminalState.getCellAt(0, 0)?.char, '█');

        // 1/4 宽 → ▎
        await tester.pumpComponent(
          MessageCard(
            color: nocterm.Color.fromRGB(106, 190, 185),
            borderWidth: 0.25,
            child: const nocterm.Text('内容', softWrap: true),
          ),
        );
        await tester.pump();
        expect(tester.terminalState.getCellAt(0, 0)?.char, '▎');
      });
    });

    test('竖条贯穿多行内容', () {
      return nocterm_test.testNocterm('竖条多行', (tester) async {
        await tester.pumpComponent(
          MessageCard(
            color: nocterm.Color.fromRGB(106, 190, 185),
            child: const nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
          ),
        );
        await tester.pump();

        for (var y = 0; y < 3; y++) {
          final cell = tester.terminalState.getCellAt(0, y);
          expect(cell?.char, '▌', reason: '第 $y 行竖条应是半块字符');
          expect(cell?.style.color?.red, 106, reason: '第 $y 行竖条应 teal');
        }
      });
    });

    test('竖条贯穿垂直 padding(内容上下留白)', () {
      return nocterm_test.testNocterm('竖条padding', (tester) async {
        await tester.pumpComponent(
          MessageCard(
            color: nocterm.Color.fromRGB(106, 190, 185),
            verticalPadding: 1,
            child: const nocterm.Text('第一行\n第二行', softWrap: true),
          ),
        );
        await tester.pump();

        // 顶部 padding + 2 行内容 + 底部 padding = 4 行竖条
        for (var y = 0; y < 4; y++) {
          final cell = tester.terminalState.getCellAt(0, y);
          expect(cell?.char, '▌', reason: '第 $y 行竖条应贯穿 padding');
        }
        // 第 5 行无竖条(内容结束)
        final cell5 = tester.terminalState.getCellAt(0, 4);
        expect(cell5?.char, isNot('▌'), reason: '内容结束后竖条应终止');
      });
    });
  });
}
