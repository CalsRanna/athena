import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

/// 文字在行盒里的垂直位置。
///
/// 行盒（22 / 18）比字体自身的 em 盒高，多出来的几像素由
/// `TextStyle.leadingDistribution` 决定分在字的上方还是上下平分：默认的
/// `proportional` 会把它按 ascender/descender 比例几乎全压在字上方，字就整体
/// 偏下。预设统一写 `even` 后，字形落在行盒中心（见 `athena_tokens.dart` 的说明）。
///
/// 这里的断言直接比较「字形墨迹中心」与「行盒中心」，而不是比较样式字段——
/// 样式写对了但被上层的替换式 `DefaultTextStyle` 抹掉时，字段断言仍然会通过。
void main() {
  for (final entry in _presets.entries) {
    test('${entry.key} 预设平分行距', () {
      expect(
        entry.value.leadingDistribution,
        TextLeadingDistribution.even,
        reason: '预设留空会退回 Flutter 默认的 proportional，字在行盒里整体偏下',
      );
    });
  }

  test('等宽元信息与预设同一口径', () {
    expect(
      AthenaTextStyle.captionCode.leadingDistribution,
      TextLeadingDistribution.even,
    );
  });

  for (final label in ['AthenaPrimaryButton', 'AthenaSecondaryButton']) {
    testWidgets('$label 的文字在按钮内垂直居中', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(AthenaColorMode.light),
          builder: (context, child) => AthenaTestScope(child: child!),
          home: Scaffold(
            body: Center(
              child: label == 'AthenaPrimaryButton'
                  ? AthenaPrimaryButton(onTap: () {}, child: const Text('TAG'))
                  : AthenaSecondaryButton(
                      onTap: () {},
                      child: const Text('TAG'),
                    ),
            ),
          ),
        ),
      );

      final button = find.byType(
        label == 'AthenaPrimaryButton'
            ? AthenaPrimaryButton
            : AthenaSecondaryButton,
      );
      _expectGlyphsCentered(tester, text: 'TAG', box: button);
    });
  }

  testWidgets('AthenaTag 的文字在胶囊内垂直居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: const Scaffold(
          body: Center(child: AthenaTag(text: 'TAG')),
        ),
      ),
    );
    _expectGlyphsCentered(tester, text: 'TAG', box: find.byType(AthenaTag));
  });

  // 分工：UI 走平台默认（fontFamily 为 null 或环境注入的值），只有代码与
  // 运行统计显式用 Fira Code。这里断言两件事——预设不夹带字族（否则按钮、
  // chip、顶栏会偏离平台默认），captionCode 确实带 Fira Code。
  testWidgets('UI 预设不带字族，元信息带 Fira Code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              for (final entry in _presets.entries)
                DefaultTextStyle(
                  style: entry.value,
                  child: Text('preset-${entry.key}'),
                ),
              const Text('mono', style: AthenaTextStyle.captionCode),
            ],
          ),
        ),
      ),
    );

    for (final key in _presets.keys) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('preset-$key'),
      );
      expect(
        paragraph.text.style?.fontFamily,
        isNot(AthenaFont.code),
        reason: '$key 不该夹带等宽字族，UI 文字应走平台默认',
      );
    }

    final mono = tester.renderObject<RenderParagraph>(find.text('mono'));
    expect(mono.text.style?.fontFamily, AthenaFont.code);
    expect(mono.text.style?.fontFamilyFallback, AthenaFont.codeFallback);
  });

  testWidgets('真实组件文字不夹带等宽字族', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const AthenaTag(text: 'tag-text'),
              AthenaPrimaryButton(onTap: () {}, child: const Text('primary')),
              AthenaSecondaryButton(
                onTap: () {},
                child: const Text('secondary'),
              ),
              AthenaTextButton(onTap: () {}, text: 'text-button'),
            ],
          ),
        ),
      ),
    );

    for (final text in ['tag-text', 'primary', 'secondary', 'text-button']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.text.style?.fontFamily,
        isNot(AthenaFont.code),
        reason: '$text 不该用等宽字族',
      );
    }
  });
}

const _presets = <String, TextStyle>{
  'hero': AthenaTextStyle.hero,
  'title': AthenaTextStyle.title,
  'section': AthenaTextStyle.section,
  'row': AthenaTextStyle.row,
  'prose': AthenaTextStyle.prose,
  'body': AthenaTextStyle.body,
  'label': AthenaTextStyle.label,
  'caption': AthenaTextStyle.caption,
};

/// 断言一行大写字母的字形在 [box] 内垂直居中。
///
/// 用 `RenderParagraph` 的字形边界（`getBoxesForSelection`）而不是整块高度：
/// 整块高度只说明行盒对齐了，说明不了字形落在哪里。测试字体的大写字母高
/// 0.7em、无下沉部，墨迹中心应当与行盒中心重合；允许 1px 的字体
/// ascender/descender 不对称残差。
void _expectGlyphsCentered(
  WidgetTester tester, {
  required String text,
  required Finder box,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(boxes, isNotEmpty, reason: '找不到 "$text" 的字形边界');

  final top = boxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);
  final bottom = boxes.map((b) => b.bottom).reduce((a, b) => a > b ? a : b);
  final glyphCenter = (top + bottom) / 2;
  final lineCenter = paragraph.size.height / 2;

  expect(
    (glyphCenter - lineCenter).abs(),
    lessThan(1.0),
    reason:
        '字形中心 $glyphCenter 与行盒中心 $lineCenter 相差 '
        '${(glyphCenter - lineCenter).toStringAsFixed(2)}px——'
        '行距没有被上下平分（leadingDistribution 丢了？）',
  );
}
