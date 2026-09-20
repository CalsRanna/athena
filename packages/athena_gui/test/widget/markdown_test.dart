import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle? _findTextStyle(InlineSpan span, String text) {
  if (span is! TextSpan) return null;
  if (span.text == text) return span.style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final style = _findTextStyle(child, text);
    if (style != null) return style;
  }
  return null;
}

Color _renderedTextColor(WidgetTester tester, String text) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final color = _findTextStyle(richText.text, text)?.color;
    if (color != null) return color;
  }
  throw TestFailure('No styled text found for "$text".');
}

TextStyle _renderedTextStyle(WidgetTester tester, String text) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final style = _findTextStyle(richText.text, text);
    if (style != null) return style;
  }
  throw TestFailure('No styled text found for "$text".');
}

Color? _renderedMathColor(WidgetTester tester) {
  final markdown = tester.widget<MarkdownBody>(
    find.byWidgetPredicate((widget) => widget is MarkdownBody),
  );
  final builder = markdown.builders['latex'] as LatexElementBuilder;
  return builder.textStyle?.color;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpMarkdown(
    WidgetTester tester,
    String content, {
    AthenaColors colors = AthenaColors.dark,
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light(),
          extensions: [colors],
        ),
        home: Scaffold(
          body: AthenaMarkdown(
            message: MessageEntity(
              chatId: 1,
              role: 'assistant',
              content: content,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses plain text for an unlabeled fenced code block', (
    tester,
  ) async {
    await pumpMarkdown(tester, '```\nhello\n```');

    expect(find.text('plain text'), findsOneWidget);
  });

  testWidgets('keeps an explicit fenced code block language', (tester) async {
    await pumpMarkdown(tester, '```dart\nvoid main() {}\n```');

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('plain text'), findsNothing);
  });

  testWidgets('does not render the parser-added trailing code block line', (
    tester,
  ) async {
    await pumpMarkdown(tester, '```\nhello\n```');

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('hello\n'), findsNothing);
  });

  testWidgets('recognizes an empty unlabeled fenced code block', (
    tester,
  ) async {
    await pumpMarkdown(tester, '```\n```');

    expect(find.text('plain text'), findsOneWidget);
  });

  testWidgets('does not add a language label to inline code', (tester) async {
    await pumpMarkdown(tester, 'Use `inline code` here.');

    expect(find.text('plain text'), findsNothing);
    expect(find.text('inline code'), findsOneWidget);
  });

  testWidgets(
    'dark code blocks sit on a recessed surface, not a bright plate',
    (tester) async {
      await pumpMarkdown(tester, '```dart\nvoid main() {}\n```');

      final block = tester.widget<Container>(
        find.byKey(const ValueKey('markdown-code-block')),
      );
      final decoration = block.decoration! as BoxDecoration;

      expect(decoration.color, AthenaColors.dark.codeBackground);
      expect(
        _renderedTextColor(tester, 'void main() {}'),
        AthenaColors.dark.textOnCode,
      );
      // 代码块底必须比页面底色更深：深色页面上不允许再出现整块亮底
      expect(
        AthenaColors.dark.codeBackground.computeLuminance(),
        lessThan(AthenaColors.dark.surface.computeLuminance()),
      );
    },
  );

  testWidgets('footnote region wears the same shell as a code block', (
    tester,
  ) async {
    const markdown = '''
```dart
void main() {}
```

First reference[^one] and second reference[^two].

[^one]: First footnote.
[^two]: Second footnote.
''';

    await pumpMarkdown(tester, markdown);

    final regionFinder = find.byKey(const ValueKey('markdown-footnotes'));
    final region = tester.widget<Container>(regionFinder);
    final codeBlock = tester.widget<Container>(
      find.byKey(const ValueKey('markdown-code-block')),
    );

    expect(regionFinder, findsOneWidget);
    expect(find.text('Footnotes'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNWidgets(2));
    // 头部只有文字标签，不带列表图标
    expect(find.byIcon(Icons.format_list_numbered_rounded), findsNothing);
    // 脚注区与代码块同壳：同底、同圆角、同宽同裁剪，且都不描边
    // （width: double.infinity 在 Container 构造期落成 constraints）
    expect(region.decoration, codeBlock.decoration);
    expect(region.clipBehavior, codeBlock.clipBehavior);
    expect(region.constraints, codeBlock.constraints);
    final decoration = region.decoration! as BoxDecoration;
    expect(decoration.color, AthenaColors.dark.codeBackground);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(decoration.border, isNull);
    // 头部标签与代码块的语言标签同规格（等宽、同号、同色）
    final label = tester.widget<Text>(find.text('Footnotes'));
    final language = tester.widget<Text>(find.text('dart'));
    expect(label.style?.fontFamily, language.style?.fontFamily);
    expect(label.style?.fontSize, language.style?.fontSize);
    expect(label.style?.color, language.style?.color);
  });

  testWidgets('does not style an ordinary ordered list as footnotes', (
    tester,
  ) async {
    await pumpMarkdown(tester, '1. First item\n2. Second item');

    expect(find.byKey(const ValueKey('markdown-footnotes')), findsNothing);
    expect(find.text('Footnotes'), findsNothing);
  });

  testWidgets('uses theme colors for links, strikethrough, and math', (
    tester,
  ) async {
    const markdown = r'[link](https://example.com) ~~removed~~ $x + 1$';

    await pumpMarkdown(tester, markdown);
    final darkColors = (
      link: _renderedTextColor(tester, 'link'),
      strikethrough: _renderedTextColor(tester, 'removed'),
      math: _renderedMathColor(tester),
    );

    await pumpMarkdown(
      tester,
      markdown,
      colors: AthenaColors.light,
      brightness: Brightness.light,
    );
    final lightColors = (
      link: _renderedTextColor(tester, 'link'),
      strikethrough: _renderedTextColor(tester, 'removed'),
      math: _renderedMathColor(tester),
    );

    expect(darkColors.link, AthenaColors.dark.markdownLink);
    expect(darkColors.strikethrough, AthenaColors.dark.markdownStrikethrough);
    expect(darkColors.math, AthenaColors.dark.markdownMath);
    expect(lightColors.link, AthenaColors.light.markdownLink);
    expect(lightColors.strikethrough, AthenaColors.light.markdownStrikethrough);
    expect(lightColors.math, AthenaColors.light.markdownMath);
    expect(darkColors.link, isNot(lightColors.link));
    expect(darkColors.strikethrough, isNot(lightColors.strikethrough));
    expect(darkColors.math, isNot(lightColors.math));
  });

  testWidgets('renders every heading level at body size, only bolded', (
    tester,
  ) async {
    const markdown = '''
# Alpha

## Bravo

### Charlie

#### Delta

##### Echo

###### Foxtrot

Body paragraph.
''';

    await pumpMarkdown(tester, markdown);

    final body = _renderedTextStyle(tester, 'Body paragraph.');
    expect(body.fontSize, isNotNull);
    for (final text in const [
      'Alpha',
      'Bravo',
      'Charlie',
      'Delta',
      'Echo',
      'Foxtrot',
    ]) {
      final style = _renderedTextStyle(tester, text);
      expect(style.fontSize, body.fontSize, reason: '$text 应与正文同号');
      expect(style.height, body.height, reason: '$text 应与正文同行高');
      expect(style.letterSpacing, body.letterSpacing);
      expect(style.fontWeight, FontWeight.bold, reason: '$text 应加粗');
      expect(style.color, body.color, reason: '$text 应与正文同色');
    }

    final markdownBody = tester.widget<MarkdownBody>(
      find.byWidgetPredicate((widget) => widget is MarkdownBody),
    );
    final sheet = markdownBody.styleSheet!;
    expect(
      [sheet.h2, sheet.h3, sheet.h4, sheet.h5, sheet.h6],
      everyElement(sheet.h1),
      reason: '六级标题共用同一套样式',
    );
    expect(sheet.h1, sheet.p!.copyWith(fontWeight: FontWeight.bold));
  });
}
