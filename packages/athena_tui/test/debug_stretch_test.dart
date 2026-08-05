import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug Row stretch 高度测量', () {
    return nt.testNocterm('stretch调试', (tester) async {
      final sc = nocterm.ScrollController();
      await tester.pumpComponent(nocterm.SingleChildScrollView(
        controller: sc,
        child: nocterm.Column(
          crossAxisAlignment: nocterm.CrossAxisAlignment.start,
          children: [
            nocterm.Row(
              crossAxisAlignment: nocterm.CrossAxisAlignment.stretch,
              children: [
                nocterm.Container(width: 1, color: nocterm.Color.fromRGB(106, 190, 185)),
                const nocterm.Padding(
                  padding: nocterm.EdgeInsets.only(left: 2),
                  child: nocterm.Text('第一行\n第二行\n第三行', softWrap: true),
                ),
              ],
            ),
          ],
        ),
      ));
      await tester.pump();
      print('内容高=${sc.maxScrollExtent + sc.viewportDimension}');
    });
  });
}
