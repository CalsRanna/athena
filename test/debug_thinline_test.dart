import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug 细线字符测试', () {
    return nt.testNocterm('细线调试', (tester) async {
      // 各种可能的"细竖线"字符,前景色 teal
      const chars = ['│', '┃', '┆', '┊', '╎', '|', '▏', '▎', '▍', '▌'];
      await tester.pumpComponent(nocterm.Column(
        crossAxisAlignment: nocterm.CrossAxisAlignment.start,
        children: [
          for (final c in chars)
            nocterm.Text('$c 字符 ${c.codeUnitAt(0)}', style: const nocterm.TextStyle(color: nocterm.Color.fromRGB(106, 190, 185))),
        ],
      ));
      await tester.pump();
      final lines = tester.terminalState.getText().split('\n');
      for (var i = 0; i < chars.length; i++) {
        print('L$i |${lines[i]}|');
      }
    });
  });
}
