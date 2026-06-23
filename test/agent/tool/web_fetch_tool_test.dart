import 'package:athena/agent/tool/web_fetch_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tool = WebFetchTool();

  group('WebFetchTool SSRF hard-block (S4)', () {
    test('still rejects a clearly invalid URL with the existing error',
        () async {
      // 'http://' 缺少 host，无法解析为合法 URI。
      final result = await tool.execute({'url': '::: not a url'});
      expect(result, startsWith('Error:'));
      expect(result, contains('Invalid URL'));
    });

    test('rejects non-http schemes', () async {
      final result = await tool.execute({'url': 'ftp://example.com/'});
      expect(result, startsWith('Error:'));
      expect(result, contains('http'));
    });
  });
}
