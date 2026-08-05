import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:test/test.dart';

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

  group('WebFetchTool SSRF literal-address block', () {
    test('blocks loopback / private / link-local literal IPs', () async {
      for (final url in [
        'http://127.0.0.1:8080/admin',
        'http://127.0.0.1/',
        'http://10.0.0.5/',
        'http://172.16.0.1/x',
        'http://172.31.255.254/x',
        'http://192.168.1.1/x',
        'http://169.254.169.254/latest/meta-data/',
        'http://100.64.0.1/',
        'http://0.0.0.0/',
        'http://[::1]/',
        'http://[fe80::1]/',
        'http://[fc00::1]/',
      ]) {
        final result = await tool.execute({'url': url});
        expect(
          result,
          startsWith('Error: Blocked:'),
          reason: 'expected blocked: $url',
        );
      }
    });

    test('blocks localhost and .local hostnames', () async {
      for (final url in [
        'http://localhost/',
        'http://localhost:3000/admin',
        'http://myhost.local/',
      ]) {
        final result = await tool.execute({'url': url});
        expect(
          result,
          startsWith('Error: Blocked:'),
          reason: 'expected blocked: $url',
        );
      }
    });

    test('blocks integer / hex numeric IP forms', () async {
      for (final url in [
        'http://2130706433/', // 127.0.0.1
        'http://0x7f000001/',
      ]) {
        final result = await tool.execute({'url': url});
        expect(
          result,
          startsWith('Error: Blocked:'),
          reason: 'expected blocked: $url',
        );
      }
    });

    test('domain names are NOT blocked (proxy-environment regression)', () async {
      // 域名不做 DNS 解析与拦截（fake-ip 代理兼容）。
      // 结果可以是成功或网络错误，但绝不包含 Blocked。
      final result = await tool.execute({'url': 'https://example.com/'});
      expect(result, isNot(contains('Blocked')));
    });
  });
}
