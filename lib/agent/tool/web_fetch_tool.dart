import 'package:http/http.dart' as http;

import 'html_to_markdown.dart';
import 'tool_interface.dart';

class WebFetchTool implements Tool {
  static const _maxResponseBytes = 200 * 1024; // 200KB
  static const _defaultTimeout = Duration(seconds: 30);

  @override
  String get name => 'web_fetch';

  @override
  String get description => 'Fetch content from a URL and return it as '
      'Markdown (default) or raw HTML. '
      'Markdown mode strips unnecessary tags and converts the page to '
      'readable text — ideal for most tasks. '
      'HTML mode preserves the original markup for structural analysis. '
      'Response is capped at 200KB.\n'
      'Referer and X-Title headers may be added automatically by the client.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The URL to fetch. Must be http or https.',
          },
          'method': {
            'type': 'string',
            'enum': ['GET', 'POST'],
            'description': 'HTTP method. Defaults to GET.',
          },
          'format': {
            'type': 'string',
            'enum': ['markdown', 'html'],
            'description':
                'Output format. "markdown" (default) converts HTML to '
                'clean readable text. "html" returns the raw HTML (useful '
                'for analyzing page structure, extracting specific elements, '
                'or debugging markup).',
          },
          'headers': {
            'type': 'object',
            'description': 'Optional HTTP headers as key-value pairs.',
          },
          'body': {
            'type': 'string',
            'description': 'Request body for POST requests.',
          },
        },
        'required': ['url'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final method = args['method'] as String? ?? 'GET';
    final format = args['format'] as String? ?? 'markdown';
    final headers = (args['headers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        {};
    final body = args['body'] as String?;

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'Error: Invalid URL: $url';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Error: Only http and https URLs are allowed';
    }
    try {
      final client = http.Client();
      http.Response response;
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await client
                .get(uri, headers: headers)
                .timeout(_defaultTimeout);
            break;
          case 'POST':
            response = await client
                .post(uri, headers: headers, body: body)
                .timeout(_defaultTimeout);
            break;
          default:
            return 'Error: Unsupported method: $method';
        }
      } finally {
        client.close();
      }

      final totalBytes = response.body.length;
      final tooLarge = totalBytes > _maxResponseBytes;
      final raw = tooLarge
          ? response.body.substring(0, _maxResponseBytes)
          : response.body;

      // Markdown 模式且响应看起来像 HTML 时才转换
      final contentType = response.headers['content-type'] ?? '';
      final looksLikeHtml =
          contentType.contains('text/html') || _hasHtmlTags(raw);

      final output = (format == 'markdown' && looksLikeHtml)
          ? htmlToMarkdown(raw)
          : raw;

      final result = StringBuffer();
      result.writeln('Status: ${response.statusCode}');
      if (response.reasonPhrase != null &&
          response.reasonPhrase!.isNotEmpty) {
        result.writeln('Reason: ${response.reasonPhrase}');
      }
      result.writeln(
          'Content-Type: ${contentType.isNotEmpty ? contentType : '(unknown)'}');
      result.writeln();

      if (tooLarge) {
        result.writeln(output);
        result.writeln();
        result.writeln(
            '[Response truncated: ${totalBytes - _maxResponseBytes} bytes '
            'skipped (limit ${_maxResponseBytes ~/ 1024}KB / '
            '${totalBytes ~/ 1024}KB total)]');
        result.writeln(
            'Hint: to reduce payload, use a more specific URL or API '
            'endpoint, add query parameters to filter results, or retry '
            'with Accept-Encoding: gzip if the server supports it.');
      } else {
        result.write(output);
      }

      return result.toString();
    } on http.ClientException catch (e) {
      return 'Error: Request failed: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 简单试探：检测文本是否包含 HTML 标签。
  static bool _hasHtmlTags(String text) {
    final upper = text.length > 2000 ? text.substring(0, 2000) : text;
    return RegExp(r'<\s*(html|head|body|div|p|h[1-6]|span|a\s|table)',
            caseSensitive: false)
        .hasMatch(upper);
  }
}
