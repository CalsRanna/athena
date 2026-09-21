// 临时验证：上下文条上的 chip hover 后与条底色的实际像素差。
// 用完即删（本仓 athena_gui 没有测试套件）。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const kBarKey = Key('bar');
const kChipKey = Key('chip');

Future<_Pixels> _render(WidgetTester tester, AthenaColorMode mode) async {
  final colors = colorsOf(mode);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAthenaThemeData(mode),
      home: RepaintBoundary(
        key: boundaryKey,
        child: ColoredBox(
          color: const Color(0xFF00FF00), // 画布用显眼色，便于区分
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              key: kBarKey,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: colors.surfaceButtonSecondary,
                borderRadius: BorderRadius.circular(AthenaRadius.container),
              ),
              child: AthenaContextChip(
                key: kChipKey,
                label: 'Athena',
                onTap: () {},
                filled: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  Future<ui.Image> grab() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage();
  }

  Future<int> pixel(ui.Image img, Offset at) async {
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    final x = at.dx.round().clamp(0, img.width - 1);
    final y = at.dy.round().clamp(0, img.height - 1);
    final i = (y * img.width + x) * 4;
    return (0xFF << 24) | (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
  }

  final chipRect = tester.getRect(find.byKey(kChipKey));
  final barRect = tester.getRect(find.byKey(kBarKey));
  final chipPoint = chipRect.center;
  // 条上 chip 之外的一点（条左内边距里）
  final barPoint = Offset(barRect.left + 2, barRect.center.dy);

  final restImage = await grab();
  final restChip = await pixel(restImage, chipPoint);
  final restBar = await pixel(restImage, barPoint);

  // hover：用鼠标指针移进 chip
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await tester.pump();
  await mouse.moveTo(chipPoint);
  await tester.pumpAndSettle();

  final hoverChip = await pixel(await grab(), chipPoint);
  final hoverBar = await pixel(await grab(), barPoint);
  await mouse.removePointer();
  await tester.pumpAndSettle();

  return _Pixels(
    restChip: restChip,
    restBar: restBar,
    hoverChip: hoverChip,
    hoverBar: hoverBar,
  );
}

class _Pixels {
  final int restChip;
  final int restBar;
  final int hoverChip;
  final int hoverBar;
  _Pixels({
    required this.restChip,
    required this.restBar,
    required this.hoverChip,
    required this.hoverBar,
  });
}

String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

int _delta(int a, int b) {
  int ch(int c, int shift) => (c >> shift) & 0xFF;
  var max = 0;
  for (final s in [0, 8, 16]) {
    final d = (ch(a, s) - ch(b, s)).abs();
    if (d > max) max = d;
  }
  return max;
}

void main() {
  for (final mode in [AthenaColorMode.light, AthenaColorMode.dark]) {
    testWidgets('context chip hover delta ($mode)', (tester) async {
      tester.view.physicalSize = const ui.Size(400, 100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final p = await _render(tester, mode);
      // ignore: avoid_print
      print('[$mode] bar=${_hex(p.restBar)} chip-rest=${_hex(p.restChip)} '
          'chip-hover=${_hex(p.hoverChip)} hoverBar=${_hex(p.hoverBar)} '
          'delta(bar,hover)=${_delta(p.restBar, p.hoverChip)}');
      expect(p.hoverBar, p.restBar, reason: '条底色不应随 chip hover 变化');
      expect(_delta(p.restBar, p.hoverChip), greaterThanOrEqualTo(10));
    });
  }
}
