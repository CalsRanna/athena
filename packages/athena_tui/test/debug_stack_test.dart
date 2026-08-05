import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug Stack 高度拆解', () {
    return nt.testNocterm('Stack调试', (tester) async {
      Future<void> measure(String name, nocterm.Component comp) async {
        final sc = nocterm.ScrollController();
        await tester.pumpComponent(nocterm.SingleChildScrollView(
          controller: sc,
          child: nocterm.Column(
            crossAxisAlignment: nocterm.CrossAxisAlignment.start,
            children: [comp],
          ),
        ));
        await tester.pump();
        print('$name 内容高=${sc.maxScrollExtent + sc.viewportDimension}');
      }

      // 纯 Stack + 内容
      await measure('纯Stack', nocterm.Stack(
        children: const [
          nocterm.Padding(
            padding: nocterm.EdgeInsets.only(left: 2),
            child: nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
          ),
        ],
      ));
      // Stack + positioned 竖条(top/bottom)
      await measure('Stack+positioned', nocterm.Stack(
        children: [
          const nocterm.Padding(
            padding: nocterm.EdgeInsets.only(left: 2),
            child: nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
          ),
          nocterm.Positioned(
            top: 0, bottom: 0, left: 0, width: 1,
            child: nocterm.Container(width: 1, color: nocterm.Color.fromRGB(106, 190, 185)),
          ),
        ],
      ));
    });
  });
}
