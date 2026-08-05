import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:nocterm/src/test/nocterm_tester.dart' as nt;
import 'package:test/test.dart';

void main() {
  test('debug 负 margin 精确测量', () {
    return nt.testNocterm('负margin调试', (tester) async {
      nocterm.Component card(String text, {double marginBottom = 0}) =>
          nocterm.Container(
            margin: nocterm.EdgeInsets.only(bottom: marginBottom),
            padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
            decoration: const nocterm.BoxDecoration(
              border: nocterm.BoxBorder(
                left: nocterm.BorderSide(color: nocterm.Color.fromRGB(255, 255, 255)),
              ),
            ),
            child: nocterm.Text(text, softWrap: true),
          );

      for (final mb in [0.0, -1.0]) {
        final sc = nocterm.ScrollController();
        await tester.pumpComponent(nocterm.SingleChildScrollView(
          controller: sc,
          child: nocterm.Column(
            crossAxisAlignment: nocterm.CrossAxisAlignment.start,
            children: [for (var i = 0; i < 6; i++) card('卡片$i', marginBottom: mb)],
          ),
        ));
        await tester.pump();
        final total = sc.maxScrollExtent + sc.viewportDimension;
        final perCard = total / 6;
        print('marginBottom=$mb 单卡高=$perCard');
      }
    });
  });
}
