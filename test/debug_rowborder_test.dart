import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug 彩色 Container 竖条', () {
    return nt.testNocterm('Row边框调试', (tester) async {
      // 空 Container 彩色背景(width 1) + 多行内容
      await tester.pumpComponent(nocterm.Row(
        crossAxisAlignment: nocterm.CrossAxisAlignment.start,
        children: [
          nocterm.Container(
            width: 1,
            height: 3,
            color: nocterm.Color.fromRGB(106, 190, 185),
          ),
          const nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
        ],
      ));
      await tester.pump();
      final lines = tester.terminalState.getText().split('\n');
      for (var i = 0; i < 5; i++) {
        print('L$i |${lines[i]}|');
      }
    });
  });
}
