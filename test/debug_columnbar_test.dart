import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug Column+Expanded 竖条', () {
    return nt.testNocterm('Column竖条调试', (tester) async {
      await tester.pumpComponent(nocterm.Row(
        crossAxisAlignment: nocterm.CrossAxisAlignment.start,
        children: [
          nocterm.Column(
            crossAxisAlignment: nocterm.CrossAxisAlignment.start,
            children: [
              nocterm.Expanded(
                child: nocterm.Container(width: 1, color: nocterm.Color.fromRGB(106, 190, 185)),
              ),
            ],
          ),
          const nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
        ],
      ));
      await tester.pump();
      final state = tester.terminalState;
      final lines = state.getText().split('\n');
      for (var i = 0; i < 5; i++) {
        final bg = state.getCellAt(0, i)?.style.backgroundColor;
        final prefix = bg != null ? '▓' : '·';
        print('L$i $prefix |${lines[i].replaceAll(' ', '·')}|');
      }
    });
  });
}
