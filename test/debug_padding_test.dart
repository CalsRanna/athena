import 'package:athena_tui/ui/widgets/message_card.dart';
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug 垂直 padding 竖条行数', () {
    return nt.testNocterm('padding调试', (tester) async {
      // 内容带垂直 padding(0.5 → 各取整 1 行)
      await tester.pumpComponent(MessageCard(
        color: nocterm.Color.fromRGB(106, 190, 185),
        child: const nocterm.Padding(
          padding: nocterm.EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
          child: nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
        ),
      ));
      await tester.pump();
      final lines = tester.terminalState.getText().split('\n');
      // 内容 3 行 + 上下 padding 各 1 = 5 行;检查前 5 行竖条
      for (var y = 0; y < 6; y++) {
        final cell = tester.terminalState.getCellAt(0, y);
        final bar = cell?.char == '▌' ? '▓' : '·';
        print('L$y $bar |${lines[y]}|');
      }
    });
  });
}
