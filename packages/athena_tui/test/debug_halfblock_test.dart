import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug 半块字符宽度', () {
    return nt.testNocterm('半块调试', (tester) async {
      // 各半块字符的宽度
      for (final c in ['▌', '▍', '▎', '▏', '█', '▓', '▒', '░']) {
        await tester.pumpComponent(nocterm.Text(c, style: const nocterm.TextStyle(color: nocterm.Color.fromRGB(106, 190, 185))));
        await tester.pump();
        final cell0 = tester.terminalState.getCellAt(0, 0);
        final cell1 = tester.terminalState.getCellAt(1, 0);
        final w = cell0?.width;
        final second = cell1?.char;
        print('$c (U+${c.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}) 宽=$w 占用第2格=${second != null && second != ' '}');
      }
    });
  });
}
