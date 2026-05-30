import 'package:http/http.dart' as http;

import 'tool_interface.dart';
import 'url_safety.dart';

class WebFetchTool implements Tool {
  static const _maxResponseBytes = 1024 * 1024;
  static const _defaultTimeout = Duration(seconds: 30);

  @override
  String get name => 'web_fetch';

  @override
  String get description => 'Fetch content from a URL. '
      'Use when you need to read web pages, API responses, or documentation. '
      'Response is capped at 1MB.';

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

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
    // 链路本地/云元数据地址硬拦：审批也无法覆盖，在任何网络请求前返回。
    if (classifyUrlHost(url) == UrlHostClass.linkLocal) {
      return 'Error: Refusing to fetch link-local/cloud-metadata address ($url). '
          'This is blocked to prevent SSRF and cloud-credential theft.';
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

      final truncated = response.body.length > _maxResponseBytes
          ? '${response.body.substring(0, _maxResponseBytes)}\n\n... [truncated at 1MB, '
              'total size: ${response.body.length} bytes]'
          : response.body;

      final result = StringBuffer();
      result.writeln('Status: ${response.statusCode}');
      if (response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty) {
        result.writeln('Reason: ${response.reasonPhrase}');
      }
      result.writeln();
      result.write(truncated);
      return result.toString();
    } on http.ClientException catch (e) {
      return 'Error: Request failed: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
