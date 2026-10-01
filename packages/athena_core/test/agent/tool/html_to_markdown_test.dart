import 'package:athena_core/agent/tool/html_to_markdown.dart';
import 'package:test/test.dart';

void main() {
  test('inline markup preserves word boundaries', () {
    expect(
      htmlToMarkdown('<p>Hello <b>world</b> again</p>'),
      'Hello **world** again',
    );
  });

  test(
    'code retains indentation, tabs, blank lines and a separate closing fence',
    () {
      const code = 'if (ok) {\n\treturn 1;\n\n\n}\n';
      expect(htmlToMarkdown('<pre><code>$code</code></pre>'), '```\n$code```');
      expect(htmlToMarkdown('<pre>x</pre>'), '```\nx\n```');
      expect(htmlToMarkdown('<pre>```</pre>'), '````\n```\n````');
    },
  );

  test('HTML entities are decoded exactly once', () {
    expect(htmlToMarkdown('<p>&amp;lt; literal</p>'), '&lt; literal');
  });

  test('relative links and images use page URL or document base', () {
    final page = Uri.parse('https://example.com/docs/index.html');
    expect(
      htmlToMarkdown(
        '<a href="guide">Guide</a><img src="../img.png">',
        pageUrl: page,
      ),
      '[Guide](https://example.com/docs/guide)![](https://example.com/img.png)',
    );
    expect(
      htmlToMarkdown(
        '<base href="/assets/"><a href="guide">Guide</a>',
        pageUrl: page,
      ),
      '[Guide](https://example.com/assets/guide)',
    );
  });
}
