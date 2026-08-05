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

    test('竖条按实际宽度精确软换行(不撑高)', () {
      return nocterm_test.testNocterm(
        '竖条精确换行',
        (tester) async {
          // 终端宽 20 → 文本可用宽度 17(20 - 竖条 1 列 - 水平 padding 2)。
          // 60 个 ASCII 字符按 17 列软换行 → 4 行;竖条 = 4 + 上下 padding 各 1 = 6 行。
          await tester.pumpComponent(
            MessageCard(
              color: nocterm.Color.fromRGB(106, 190, 185),
              child: nocterm.Text('a' * 60, softWrap: true),
            ),
          );
          await tester.pump();

          for (var y = 0; y < 6; y++) {
            final cell = tester.terminalState.getCellAt(0, y);
            expect(cell?.char, '▌', reason: '第 $y 行竖条应贯穿软换行后的全部 6 行');
          }
          // 不撑高:第 7 行无竖条,内容最后一行(第 4 行,60 = 17+17+17+9)在 y=4
          final cell6 = tester.terminalState.getCellAt(0, 6);
          expect(cell6?.char, isNot('▌'), reason: '竖条行数应精确等于内容行数 + padding,不撑高');
          // 内容区从 x=2 开始(竖条 x=0 + 水平 padding x=1)
          expect(tester.terminalState.getCellAt(2, 4)?.char, 'a',
              reason: '内容最后一行应渲染在 y=4');
        },
        size: const nocterm.Size(20, 24),
      );
    });

    test('CJK 宽字符按双列宽度精确换行', () {
      return nocterm_test.testNocterm(
        '竖条CJK换行',
        (tester) async {
          // 11 个汉字(每字占 2 列,共 22)在 17 列宽度下换行为 2 行:
          // 第一行 8 字(16 列),第二行 3 字(6 列)。竖条 = 2 + 2 = 4 行。
          await tester.pumpComponent(
            MessageCard(
              color: nocterm.Color.fromRGB(106, 190, 185),
              child: nocterm.Text('汉' * 11, softWrap: true),
            ),
          );
          await tester.pump();

          for (var y = 0; y < 4; y++) {
            final cell = tester.terminalState.getCellAt(0, y);
            expect(cell?.char, '▌', reason: '第 $y 行竖条应贯穿 CJK 换行后的全部 4 行');
          }
          // 第 5 行无竖条(不撑高);第二行内容从 y=2 开始
          expect(tester.terminalState.getCellAt(0, 4)?.char, isNot('▌'),
              reason: '第 5 行无竖条');
          // 内容区从 x=2 开始(竖条 x=0 + 水平 padding x=1)
          expect(tester.terminalState.getCellAt(2, 2)?.char, '汉',
              reason: '第二行内容应渲染在 y=2');
        },
        size: const nocterm.Size(20, 24),
      );
    });
  });
}
