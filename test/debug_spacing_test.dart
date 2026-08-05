import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

// 复刻 _Card 结构(带 margin bottom 1 + 左边框)
class _Card extends nocterm.StatelessComponent {
  const _Card({required this.child});
  final nocterm.Component child;
  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return nocterm.Container(
      margin: const nocterm.EdgeInsets.only(bottom: 1),
      padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
      decoration: const nocterm.BoxDecoration(
        border: nocterm.BoxBorder(
          left: nocterm.BorderSide(color: nocterm.Color.fromRGB(255, 255, 255)),
        ),
      ),
      child: child,
    );
  }
}

void main() {
  test('debug 卡片间距', () {
    return nt.testNocterm('间距调试', (tester) async {
      await tester.pumpComponent(nocterm.Column(
        crossAxisAlignment: nocterm.CrossAxisAlignment.start,
        children: const [
          _Card(child: nocterm.Text('卡片A内容', softWrap: true)),
          _Card(child: nocterm.Text('卡片B内容', softWrap: true)),
        ],
      ));
      await tester.pump();
      final lines = tester.terminalState.getText().split('\n');
      for (var i = 0; i < lines.length; i++) {
        print('L${i.toString().padLeft(2)} |${lines[i]}|');
      }
    });
  });
}
